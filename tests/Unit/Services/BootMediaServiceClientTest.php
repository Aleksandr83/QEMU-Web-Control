<?php

namespace Tests\Unit\Services;

use App\Services\BootMediaServiceClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class BootMediaServiceClientTest extends TestCase
{
    use RefreshDatabase;

    private string $baseUrl = 'http://localhost:50052';

    public function test_delete_paths_success(): void
    {
        Http::fake([
            $this->baseUrl . '/delete' => Http::response(['results' => [
                ['path' => '/srv/iso/test.iso', 'success' => true, 'error_message' => ''],
            ]], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->deletePaths(['/srv/iso/test.iso']);

        $this->assertNotNull($result);
        $this->assertArrayHasKey('results', $result);
        $this->assertCount(1, $result['results']);
        $this->assertTrue($result['results'][0]['success']);
    }

    public function test_delete_paths_empty_array_returns_results(): void
    {
        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->deletePaths([]);

        $this->assertEquals(['results' => []], $result);
        Http::assertNothingSent();
    }

    public function test_health_success(): void
    {
        Http::fake([
            $this->baseUrl . '/health' => Http::response(['status' => 'ok'], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $this->assertTrue($client->health());
    }

    public function test_health_failure(): void
    {
        Http::fake([
            $this->baseUrl . '/health' => Http::response([], 500),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $this->assertFalse($client->health());
    }

    public function test_move_iso_success(): void
    {
        Http::fake([
            $this->baseUrl . '/move' => Http::response(['operation_id' => 'op-123'], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->moveIso('op-123', 'test.iso', '/srv/iso');

        $this->assertNotNull($result);
        $this->assertArrayNotHasKey('error', $result);
        $this->assertEquals('op-123', $result['operation_id']);
    }

    public function test_move_iso_returns_error_on_failure(): void
    {
        Http::fake([
            $this->baseUrl . '/move' => Http::response(['error' => 'Source file does not exist'], 400),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->moveIso('op-123', 'missing.iso', '/srv/iso');

        $this->assertNotNull($result);
        $this->assertArrayHasKey('error', $result);
        $this->assertEquals('Source file does not exist', $result['error']);
    }

    public function test_get_progress_success(): void
    {
        Http::fake([
            $this->baseUrl . '/progress/op-123' => Http::response([
                'operation_id' => 'op-123',
                'status' => 'running',
                'progress' => 50,
            ], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->getProgress('op-123');

        $this->assertNotNull($result);
        $this->assertEquals('running', $result['status']);
        $this->assertEquals(50, $result['progress']);
    }

    public function test_cancel_move_success(): void
    {
        Http::fake([
            $this->baseUrl . '/cancel' => Http::response(['cancelled' => true], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl);
        $result = $client->cancelMove('op-123');

        $this->assertNotNull($result);
        $this->assertTrue($result['cancelled']);
    }

    public function test_move_iso_with_api_key_sends_headers(): void
    {
        Http::fake([
            $this->baseUrl . '/move' => Http::response(['operation_id' => 'op-1'], 200),
        ]);

        $client = new BootMediaServiceClient($this->baseUrl, 'secret-key');
        $client->moveIso('op-1', 'test.iso', '/srv/iso');

        Http::assertSent(function ($request) {
            return str_contains($request->url(), '/move')
                && $request->hasHeader('X-API-Key')
                && $request->header('X-API-Key')[0] === 'secret-key'
                && $request->hasHeader('X-Signature');
        });
    }
}
