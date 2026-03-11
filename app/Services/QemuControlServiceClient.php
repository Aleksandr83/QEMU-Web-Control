<?php

namespace App\Services;

use App\Models\InfoLog;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class QemuControlServiceClient
{
    private const SERVICE_NAME = 'QemuControlService';

    public function __construct(
        private readonly string $baseUrl
    ) {
    }

    public function startVm(array $params): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/start';
        try {
            $response = Http::timeout(15)->post($url, $params);
            $body = $response->json();
            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $params,
                $body ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'start'
            );
            if ($response->successful()) {
                return $body;
            }
            Log::warning('QemuControlService start failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            return null;
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $params, null, null, $e->getMessage(), 'start');
            Log::error('QemuControlService start error: ' . $e->getMessage());
            return null;
        }
    }

    public function stopVm(string $vmId, ?int $pid = null): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/stop';
        $request = ['vm_id' => $vmId, 'pid' => $pid ?? 0];
        try {
            $response = Http::timeout(10)->post($url, $request);
            $body = $response->json();
            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                $body ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'stop'
            );
            if ($response->successful()) {
                return $body;
            }
            return null;
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'stop');
            Log::error('QemuControlService stop error: ' . $e->getMessage());
            return null;
        }
    }

    public function getStatus(string $vmId): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/status';
        $request = ['vm_id' => $vmId];
        try {
            $response = Http::timeout(5)->post($url, $request);
            $body = $response->json();
            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                $request,
                $body ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'status'
            );
            if ($response->successful()) {
                return $body;
            }
            return null;
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'status');
            Log::error('QemuControlService status error: ' . $e->getMessage());
            return null;
        }
    }

    public function capturePreview(string $vmId, ?string $uuid = null): array
    {
        $url = rtrim($this->baseUrl, '/') . '/preview';
        $request = ['vm_id' => $vmId];
        if ($uuid !== null && $uuid !== '') {
            $request['uuid'] = $uuid;
        }
        try {
            $response = Http::timeout(10)->post($url, $request);
            $contentType = $response->header('Content-Type') ?? '';
            if (str_contains($contentType, 'json')) {
                $body = $response->json() ?? [];
                $errMsg = $body['error_message'] ?? 'Unknown error';
                InfoLog::log(
                    self::SERVICE_NAME,
                    'POST',
                    $url,
                    $request,
                    ['error_message' => $errMsg],
                    $response->status(),
                    $errMsg,
                    'preview'
                );
                Log::warning('QemuControlService preview failed', ['vm_id' => $vmId, 'error_message' => $errMsg]);
                return ['data' => null, 'error_message' => $errMsg];
            }
            if (!$response->successful()) {
                $errMsg = ($response->json() ?? [])['error_message'] ?? $response->body();
                InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, ['error_message' => $errMsg], $response->status(), $errMsg, 'preview');
                return ['data' => null, 'error_message' => $errMsg];
            }
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, ['size' => strlen($response->body())], $response->status(), null, 'preview');
            return ['data' => $response->body(), 'error_message' => null];
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'preview');
            Log::error('QemuControlService preview error: ' . $e->getMessage());
            return ['data' => null, 'error_message' => $e->getMessage()];
        }
    }

    public function sendText(string $vmId, ?string $uuid, string $text, string $keyboardLayout = ''): ?array
    {
        $url = rtrim($this->baseUrl, '/') . '/send-text';
        $request = ['vm_id' => $vmId, 'text' => $text];
        if ($uuid !== null && $uuid !== '') {
            $request['uuid'] = $uuid;
        }
        if ($keyboardLayout !== '') {
            $request['keyboard_layout'] = $keyboardLayout;
        }
        try {
            $response = Http::timeout(60)->post($url, $request);
            $body = $response->json();
            InfoLog::log(
                self::SERVICE_NAME,
                'POST',
                $url,
                ['vm_id' => $vmId, 'text_length' => strlen($text)],
                $body ?? ['body' => $response->body()],
                $response->status(),
                $response->successful() ? null : $response->body(),
                'send-text'
            );
            if ($response->successful()) {
                return $body;
            }
            return null;
        } catch (\Throwable $e) {
            InfoLog::log(self::SERVICE_NAME, 'POST', $url, $request, null, null, $e->getMessage(), 'send-text');
            Log::error('QemuControlService send-text error: ' . $e->getMessage());
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
}
