<?php

namespace App\Services;

use App\Models\InfoLog;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class BootMediaServiceClient
{
    private const SERVICE_NAME = 'BootMediaService';

    public function __construct(
        private readonly string $baseUrl,
        private readonly ?string $apiKey = null
    ) {
    }

    public function deletePaths(array $paths): ?array
    {
        $paths = array_values(array_filter($paths, fn ($p) => is_string($p) && $p !== ''));

        if (empty($paths)) {
            return ['results' => []];
        }

        $url = rtrim($this->baseUrl, '/') . '/delete';
        $request = ['paths' => $paths];
        $json = json_encode($request);

        try {
            if ($this->apiKey !== null && $this->apiKey !== '') {
                $signature = hash_hmac('sha256', $json, $this->apiKey, false);
                $response = Http::timeout(10)
                    ->withBody($json, 'application/json')
                    ->withHeaders([
                        'X-API-Key' => $this->apiKey,
                        'X-Signature' => $signature,
                    ])
                    ->post($url);
            } else {
                $response = Http::timeout(10)->post($url, $request);
            }

            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                $response->json() ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'delete'
            );

            if ($response->successful()) {
                return $response->json();
            }

            if ($response->status() === 429) {
                return null;
            }

            return null;
        } catch (\Throwable $e) {
            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                null,
                null,
                $e->getMessage(),
                'delete'
            );
            return null;
        }
    }

    public function health(): bool
    {
        $url = rtrim($this->baseUrl, '/') . '/health';
        try {
            $response = Http::timeout(3)->get($url);
            InfoLog::log(self::SERVICE_NAME, 'GET', $url, null, ['status' => $response->status()], $response->status(), null, 'health');
            return $response->successful();
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'GET', $url, null, null, null, $e->getMessage(), 'health');
            return false;
        }
    }

    public function moveIso(string $operationId, string $sourceFilename, string $destinationDirectory): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/move';
        $request = [
            'operation_id' => $operationId,
            'source_filename' => $sourceFilename,
            'destination_directory' => $destinationDirectory,
        ];
        $json = json_encode($request);

        try {
            if ($this->apiKey !== null && $this->apiKey !== '') {
                $signature = hash_hmac('sha256', $json, $this->apiKey, false);
                $response = Http::timeout(10)
                    ->withBody($json, 'application/json')
                    ->withHeaders([
                        'X-API-Key' => $this->apiKey,
                        'X-Signature' => $signature,
                    ])
                    ->post($url);
            } else {
                $response = Http::timeout(10)->post($url, $request);
            }

            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                $response->json() ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'move'
            );

            if ($response->successful()) {
                return $response->json();
            }
            return ['error' => $response->json('error') ?? $response->body()];
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'move');
            return null;
        }
    }

    public function getProgress(string $operationId): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/progress/' . urlencode($operationId);
        $cacheKey = 'boot_media_progress_first_logged_' . $operationId;

        try {
            $response = Http::timeout(5)->get($url);
            $data = $response->json();
            $status = $data['status'] ?? null;
            $isTerminal = in_array($status, ['completed', 'failed', 'cancelled'], true);
            $isFirst = !Cache::has($cacheKey);

            if ($isFirst || $isTerminal) {
                InfoLog::log(
                    self::SERVICE_NAME,
                    'GET',
                    $url,
                    null,
                    $data ?? ['body' => $response->body()],
                    $response->status(),
                    null,
                    'progress'
                );
            }
            if ($isFirst) {
                Cache::put($cacheKey, true, now()->addHours(1));
            }
            if ($isTerminal) {
                Cache::forget($cacheKey);
            }

            if ($response->successful()) {
                return $data;
            }
            return null;
        } catch (\Throwable $e) {
            if (!Cache::has($cacheKey)) {
                InfoLog::log(self::SERVICE_NAME, 'GET', $url, null, null, null, $e->getMessage(), 'progress');
            }
            return null;
        }
    }

    public function cancelMove(string $operationId): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/cancel';
        $request = ['operation_id' => $operationId];
        $json = json_encode($request);

        try {
            if ($this->apiKey !== null && $this->apiKey !== '') {
                $signature = hash_hmac('sha256', $json, $this->apiKey, false);
                $response = Http::timeout(5)
                    ->withBody($json, 'application/json')
                    ->withHeaders([
                        'X-API-Key' => $this->apiKey,
                        'X-Signature' => $signature,
                    ])
                    ->post($url);
            } else {
                $response = Http::timeout(5)->post($url, $request);
            }

            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                $response->json() ?? ['body' => $response->body()],
                $response->status(),
                null,
                'cancel'
            );

            if ($response->successful()) {
                return $response->json();
            }
            return null;
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'cancel');
            return null;
        }
    }
}
