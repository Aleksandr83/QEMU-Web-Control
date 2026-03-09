<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Services\BootMediaServiceClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\UploadedFile;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class BootMediaController extends Controller
{
    public function index(): View
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $isoList = $this->scanIsoFiles();
        $directories = $this->allDirectories();
        $uploadPaths = $this->uploadPaths();
        $stagingDir = config('qemu.iso_upload_staging');

        return view('boot-media.index', compact('isoList', 'directories', 'uploadPaths', 'stagingDir'));
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $targetDir = $request->input('target_dir');
        $allowedDirs = $this->uploadPaths();
        if (empty($allowedDirs) || !in_array($targetDir, $allowedDirs, true)) {
            $msg = __('ui.boot_media.upload_disabled');
            $this->logUploadError($msg, ['target_dir' => $targetDir]);
            return response()->json(['error' => $msg], 403);
        }

        $maxBytes = 10 * 1024 * 1024 * 1024;
        $request->validate([
            'iso' => [
                'required',
                'file',
                'max:' . $maxBytes,
                function ($attr, $value, $fail) {
                    if (!str_ends_with(strtolower($value->getClientOriginalName()), '.iso')) {
                        $fail(__('ui.boot_media.invalid_format'));
                    }
                },
            ],
        ], [
            'iso.required' => __('ui.boot_media.select_file'),
            'iso.max' => __('ui.boot_media.file_too_large'),
        ]);

        /** @var UploadedFile $file */
        $file = $request->file('iso');
        $name = preg_replace('/[^a-zA-Z0-9_.-]/', '_', $file->getClientOriginalName());
        if (!str_ends_with(strtolower($name), '.iso')) {
            $name .= '.iso';
        }

        $stagingDir = config('qemu.iso_upload_staging');
        if (!is_dir($stagingDir)) {
            @mkdir($stagingDir, 0755, true);
        }
        if (!is_dir($stagingDir) || !is_writable($stagingDir)) {
            $msg = __('ui.boot_media.upload_disabled');
            $this->logUploadError($msg, ['staging_dir' => $stagingDir]);
            return response()->json(['error' => $msg], 500);
        }

        $fileSize = $file->getSize();
        $sizeToCheck = ($fileSize !== false && $fileSize > 0) ? $fileSize : $maxBytes;
        if (!$this->hasEnoughSpace($stagingDir, $sizeToCheck)) {
            $msg = __('ui.boot_media.insufficient_space');
            $this->logUploadError($msg, ['staging_dir' => $stagingDir, 'required' => $sizeToCheck]);
            return response()->json(['error' => $msg], 500);
        }
        if (!$this->hasEnoughSpace($targetDir, $sizeToCheck)) {
            $msg = __('ui.boot_media.insufficient_space');
            $this->logUploadError($msg, ['target_dir' => $targetDir, 'required' => $sizeToCheck]);
            return response()->json(['error' => $msg], 500);
        }

        try {
            $file->move($stagingDir, $name);
        } catch (\Throwable $e) {
            $this->logUploadError($e->getMessage(), ['filename' => $name, 'staging_dir' => $stagingDir]);
            return response()->json(['error' => __('ui.boot_media.upload_error')], 500);
        }

        $stagingPath = rtrim($stagingDir, '/') . '/' . $name;
        if (!is_file($stagingPath) || filesize($stagingPath) === 0) {
            @unlink($stagingPath);
            $this->logUploadError(__('ui.boot_media.upload_error'), ['filename' => $name]);
            return response()->json(['error' => __('ui.boot_media.upload_error')], 500);
        }

        $client = new BootMediaServiceClient(
            config('qemu.boot_media_service_url'),
            config('qemu.boot_media_service_api_key')
        );

        $operationId = (string) \Illuminate\Support\Str::uuid();
        $result = $client->moveIso($operationId, $name, rtrim($targetDir, '/'));

        if ($result !== null && !isset($result['error'])) {
            return response()->json([
                'success' => true,
                'operation_id' => $operationId,
                'filename' => $name,
                'target_dir' => $targetDir,
                'path' => rtrim($targetDir, '/') . '/' . $name,
            ]);
        }

        if ($result !== null && isset($result['error'])) {
            @unlink($stagingPath);
            $this->logUploadError($result['error'], ['filename' => $name, 'dest' => $targetDir]);
            return response()->json(['error' => $result['error']], 400);
        }

        $destPath = rtrim($targetDir, '/') . '/' . $name;
        try {
            if (!@rename($stagingPath, $destPath)) {
                if (!@copy($stagingPath, $destPath)) {
                    throw new \RuntimeException('Copy failed');
                }
                @unlink($stagingPath);
            }
        } catch (\Throwable $e) {
            if (is_file($stagingPath)) {
                @unlink($stagingPath);
            }
            $this->logUploadError($e->getMessage(), ['filename' => $name, 'dest_path' => $destPath]);
            return response()->json(['error' => __('ui.boot_media.move_error')], 500);
        }

        ActivityLog::log(ActivityLog::TYPE_BOOT_MEDIA, 'upload', null, null, basename($destPath), null, ['path' => $destPath]);

        return response()->json([
            'success' => true,
            'message' => __('ui.boot_media.uploaded'),
            'path' => $destPath,
        ]);
    }

    public function progress(string $operationId): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $client = new BootMediaServiceClient(
            config('qemu.boot_media_service_url'),
            config('qemu.boot_media_service_api_key')
        );
        $result = $client->getProgress($operationId);

        if ($result === null) {
            return response()->json(['error' => __('ui.boot_media.service_unavailable')], 503);
        }

        return response()->json($result);
    }

    public function cancelMove(Request $request): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $operationId = $request->input('operation_id', '');
        if ($operationId === '') {
            return response()->json(['error' => 'Missing operation_id'], 400);
        }

        $client = new BootMediaServiceClient(
            config('qemu.boot_media_service_url'),
            config('qemu.boot_media_service_api_key')
        );
        $client->cancelMove($operationId);

        return response()->json(['cancelled' => true, 'operation_id' => $operationId]);
    }

    public function destroy(Request $request): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $paths = $request->input('paths', $request->input('path'));
        $paths = is_array($paths) ? $paths : [$paths];
        $paths = array_values(array_filter(array_map('strval', $paths)));

        foreach ($paths as $path) {
            if (!$this->isAllowedPath($path)) {
                return response()->json(['error' => __('ui.boot_media.delete_invalid')], 403);
            }
        }

        $client = new BootMediaServiceClient(
            config('qemu.boot_media_service_url'),
            config('qemu.boot_media_service_api_key')
        );
        $result = $client->deletePaths($paths);

        if ($result !== null) {
            $allSuccess = true;
            $anySuccess = false;
            foreach ($result['results'] ?? [] as $r) {
                if ($r['success'] ?? false) {
                    $anySuccess = true;
                    ActivityLog::log(ActivityLog::TYPE_BOOT_MEDIA, ActivityLog::ACTION_DELETE, null, null, basename($r['path']), ['path' => $r['path']], null);
                } else {
                    $allSuccess = false;
                }
            }
            if ($anySuccess) {
                return response()->json(['success' => true, 'message' => __('ui.boot_media.deleted')]);
            }
            if (!$allSuccess && !empty($result['results'])) {
                $firstError = $result['results'][0]['error_message'] ?? __('ui.boot_media.delete_invalid');
                return response()->json(['error' => $firstError], 400);
            }
        }

        foreach ($paths as $path) {
            if (@unlink($path)) {
                ActivityLog::log(ActivityLog::TYPE_BOOT_MEDIA, ActivityLog::ACTION_DELETE, null, null, basename($path), ['path' => $path], null);
                return response()->json(['success' => true, 'message' => __('ui.boot_media.deleted')]);
            }
        }

        return response()->json(['error' => __('ui.boot_media.service_unavailable')], 503);
    }

    public function download(Request $request): Response|StreamedResponse|JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $encoded = $request->query('f', '');
        $path = base64_decode(strtr($encoded, '-_', '+/'), true);
        if (!$path || !$this->isAllowedPath($path) || !is_file($path)) {
            abort(404);
        }

        ActivityLog::log(ActivityLog::TYPE_BOOT_MEDIA, 'download', null, null, basename($path), null, ['path' => $path]);

        $size = filesize($path);
        $range = $request->header('Range');

        if ($range && preg_match('/bytes=(\d+)-(\d*)/', $range, $m)) {
            $start = (int) $m[1];
            $end = isset($m[2]) && $m[2] !== '' ? (int) $m[2] : $size - 1;
            $end = min($end, $size - 1);
            $length = $end - $start + 1;

            $filename = basename($path);
            return response()->stream(function () use ($path, $start, $length) {
                $fp = fopen($path, 'rb');
                fseek($fp, $start);
                echo fread($fp, $length);
                fclose($fp);
            }, 206, [
                'Content-Type' => 'application/octet-stream',
                'Content-Length' => $length,
                'Content-Range' => sprintf('bytes %d-%d/%d', $start, $end, $size),
                'Accept-Ranges' => 'bytes',
                'Content-Disposition' => 'attachment; filename="' . addslashes($filename) . '"',
            ]);
        }

        $filename = basename($path);
        return response()->stream(function () use ($path) {
            $fp = fopen($path, 'rb');
            while (!feof($fp)) {
                echo fread($fp, 8192);
                flush();
            }
            fclose($fp);
        }, 200, [
            'Content-Type' => 'application/octet-stream',
            'Content-Length' => $size,
            'Accept-Ranges' => 'bytes',
            'Content-Disposition' => 'attachment; filename="' . addslashes($filename) . '"',
        ]);
    }

    private function isAllowedPath(string $path): bool
    {
        $path = realpath($path);
        if (!$path) {
            return false;
        }
        foreach ($this->allDirectories() as $dir) {
            $dir = realpath(rtrim($dir, '/'));
            if ($dir && (str_starts_with($path, $dir . DIRECTORY_SEPARATOR) || $path === $dir)) {
                return str_ends_with(strtolower($path), '.iso');
            }
        }
        return false;
    }

    private function allDirectories(): array
    {
        $dirs = config('qemu.iso_directories') ?: ['/var/lib/qemu/iso', '/srv/iso'];
        $fallback = config('qemu.iso_upload_fallback');
        if ($fallback && !in_array($fallback, $dirs, true)) {
            $dirs[] = $fallback;
        }
        return $dirs;
    }

    private function uploadPaths(): array
    {
        $configDirs = config('qemu.iso_upload_directories') ?? config('qemu.iso_directories') ?? ['/var/lib/qemu/iso', '/srv/iso'];
        $result = [];
        foreach ($configDirs as $dir) {
            $dir = rtrim($dir, '/');
            if (!is_dir($dir)) {
                continue;
            }
            $result[] = $dir;
        }
        if (empty($result)) {
            $fallback = rtrim((string) config('qemu.iso_upload_fallback'), '/');
            if ($fallback) {
                if (!is_dir($fallback)) {
                    @mkdir($fallback, 0755, true);
                }
                if (is_dir($fallback)) {
                    $result[] = $fallback;
                }
            }
        }
        return $result;
    }

    private function hasEnoughSpace(string $dirPath, int $requiredBytes): bool
    {
        $resolved = realpath(rtrim($dirPath, '/')) ?: $dirPath;
        $free = @disk_free_space($resolved);
        return $free !== false && $free >= $requiredBytes;
    }

    private function logUploadError(string $message, array $context = []): void
    {
        ActivityLog::log(
            ActivityLog::TYPE_ERROR,
            'upload_failed',
            null,
            null,
            'Boot Media ISO upload',
            null,
            array_merge(['message' => $message], $context)
        );
    }

    private function scanIsoFiles(): array
    {
        $result = [];
        $dirs = $this->allDirectories();

        foreach ($dirs as $dir) {
            $dir = rtrim($dir, '/');
            if (!is_dir($dir) || !is_readable($dir)) {
                continue;
            }
            foreach (scandir($dir) ?: [] as $entry) {
                if ($entry === '.' || $entry === '..' || !str_ends_with(strtolower($entry), '.iso')) {
                    continue;
                }
                $path = $dir . '/' . $entry;
                $result[] = [
                    'directory' => $dir,
                    'filename' => $entry,
                    'path' => $path,
                    'size' => is_file($path) ? filesize($path) : null,
                ];
            }
        }

        usort($result, fn($a, $b) => strcasecmp($a['filename'], $b['filename']));

        return $result;
    }
}
