<?php

namespace Tests\Unit\Services;

use App\Models\InfoLog;
use App\Services\QemuControlServiceClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class QemuControlServiceClientTest extends TestCase
{
    use RefreshDatabase;

    private string $baseUrl = 'http://localhost:50054';

    public function test_start_vm_success_creates_info_log(): void
    {
        Http::fake([
            $this->baseUrl . '/start' => Http::response(['success' => true, 'pid' => 12345], 200),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $params = [
            'vm_id' => 'vm-1',
            'primary_disk_path' => '/var/qemu/VM/disk.qcow2',
        ];
        $result = $client->startVm($params);

        $this->assertNotNull($result);
        $this->assertTrue($result['success']);
        $this->assertEquals(12345, $result['pid']);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'start')
            ->where('method', 'POST')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertEquals($this->baseUrl . '/start', $log->url);
        $this->assertEquals(200, $log->status_code);
        $this->assertEquals($params, $log->request);
    }

    public function test_stop_vm_success_creates_info_log(): void
    {
        Http::fake([
            $this->baseUrl . '/stop' => Http::response(['success' => true], 200),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->stopVm('vm-1', 12345);

        $this->assertNotNull($result);
        $this->assertTrue($result['success']);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'stop')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertEquals(['vm_id' => 'vm-1', 'pid' => 12345], $log->request);
    }

    public function test_get_status_success_creates_info_log(): void
    {
        Http::fake([
            $this->baseUrl . '/status' => Http::response(['running' => true, 'pid' => 12345], 200),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->getStatus('vm-1');

        $this->assertNotNull($result);
        $this->assertTrue($result['running']);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'status')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertEquals(['vm_id' => 'vm-1'], $log->request);
    }

    public function test_health_success_creates_info_log(): void
    {
        Http::fake([
            $this->baseUrl . '/health' => Http::response(['status' => 'ok'], 200),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $this->assertTrue($client->health());

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'health')
            ->latest()
            ->first();
        $this->assertNotNull($log);
    }

    public function test_start_vm_failure_logs_error(): void
    {
        Http::fake([
            $this->baseUrl . '/start' => Http::response(['success' => false, 'error_message' => 'VM already running'], 200),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->startVm(['vm_id' => 'vm-1', 'primary_disk_path' => '/path']);

        $this->assertNotNull($result);
        $this->assertFalse($result['success']);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'start')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertArrayHasKey('success', $log->response);
        $this->assertFalse($log->response['success']);
    }

    public function test_start_vm_http_error_logs(): void
    {
        Http::fake([
            $this->baseUrl . '/start' => Http::response([], 500),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->startVm(['vm_id' => 'vm-1', 'primary_disk_path' => '/path']);

        $this->assertNull($result);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'start')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertEquals(500, $log->status_code);
    }

    public function test_capture_preview_success_returns_image_data(): void
    {
        $pngData = "\x89PNG\r\n\x1a\n";
        Http::fake([
            $this->baseUrl . '/preview' => Http::response($pngData, 200, ['Content-Type' => 'image/png']),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->capturePreview('vm-1');

        $this->assertSame($pngData, $result['data']);
        $this->assertNull($result['error_message']);

        $log = InfoLog::where('service_name', 'QemuControlService')
            ->where('operation_type', 'preview')
            ->latest()
            ->first();
        $this->assertNotNull($log);
        $this->assertEquals(['vm_id' => 'vm-1'], $log->request);
    }

    public function test_capture_preview_failure_returns_error_message(): void
    {
        Http::fake([
            $this->baseUrl . '/preview' => Http::response(
                ['success' => false, 'error_message' => 'VM not found'],
                200,
                ['Content-Type' => 'application/json']
            ),
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->capturePreview('nonexistent');

        $this->assertNull($result['data']);
        $this->assertSame('VM not found', $result['error_message']);
    }

    public function test_capture_preview_http_exception_returns_error_message(): void
    {
        Http::fake([
            $this->baseUrl . '/preview' => function () {
                throw new \Exception('Connection refused');
            },
        ]);

        $client = new QemuControlServiceClient($this->baseUrl);
        $result = $client->capturePreview('vm-1');

        $this->assertNull($result['data']);
        $this->assertSame('Connection refused', $result['error_message']);
    }
}
