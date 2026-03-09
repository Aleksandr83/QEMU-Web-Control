<?php

namespace Tests\Unit\Services;

use App\Models\Role;
use App\Models\User;
use App\Models\VirtualMachine;
use App\Services\QemuService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

class QemuServiceTest extends TestCase
{
    use RefreshDatabase;

    private const SERVICE_URL = 'http://127.0.0.1:50054';

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config(['qemu.qemu_control_service_url' => self::SERVICE_URL]);
        config(['qemu.use_external_qemu' => true]);
        $role = Role::create(['slug' => 'user', 'name' => 'User', 'description' => '', 'color' => '', 'is_system' => true]);
        $this->user = User::create(['name' => 'Test', 'email' => 'test@test.local', 'password' => bcrypt('x')]);
        $this->user->roles()->attach($role->id);
    }

    public function test_capture_preview_returns_empty_when_vm_not_running(): void
    {
        $vm = VirtualMachine::create([
            'user_id' => $this->user->id,
            'name' => 'Test VM',
            'vm_id' => (string) Str::uuid(),
            'uuid' => (string) Str::uuid(),
            'status' => 'stopped',
            'vnc_port' => 5901,
        ]);

        $service = new QemuService();
        $result = $service->capturePreview($vm);

        $this->assertNull($result['url']);
        $this->assertNull($result['error_message']);
        Http::assertNothingSent();
    }

    public function test_capture_preview_returns_empty_when_no_vnc_port(): void
    {
        $vm = VirtualMachine::create([
            'user_id' => $this->user->id,
            'name' => 'Test VM',
            'vm_id' => (string) Str::uuid(),
            'uuid' => (string) Str::uuid(),
            'status' => 'running',
            'vnc_port' => null,
        ]);

        $service = new QemuService();
        $result = $service->capturePreview($vm);

        $this->assertNull($result['url']);
        $this->assertNull($result['error_message']);
        Http::assertNothingSent();
    }

    public function test_capture_preview_returns_empty_when_use_external_qemu_false(): void
    {
        config(['qemu.use_external_qemu' => false]);
        $vm = VirtualMachine::create([
            'user_id' => $this->user->id,
            'name' => 'Test VM',
            'vm_id' => (string) Str::uuid(),
            'uuid' => (string) Str::uuid(),
            'status' => 'running',
            'vnc_port' => 5901,
        ]);

        $service = new QemuService();
        $result = $service->capturePreview($vm);

        $this->assertNull($result['url']);
        $this->assertNull($result['error_message']);
        Http::assertNothingSent();
    }

    public function test_capture_preview_success_returns_relative_path(): void
    {
        $vmId = (string) Str::uuid();
        $uuid = (string) Str::uuid();
        $vm = VirtualMachine::create([
            'user_id' => $this->user->id,
            'name' => 'Test VM',
            'vm_id' => $vmId,
            'uuid' => $uuid,
            'status' => 'running',
            'vnc_port' => 5901,
        ]);

        $pngData = "\x89PNG\r\n\x1a\n";
        Http::fake([
            self::SERVICE_URL . '/preview' => Http::response($pngData, 200, ['Content-Type' => 'image/png']),
        ]);

        $service = new QemuService();
        $result = $service->capturePreview($vm);

        $this->assertSame('storage/vm-previews/' . $uuid . '.png', $result['url']);
        $this->assertNull($result['error_message']);
        $this->assertFileExists(storage_path('app/public/vm-previews/' . $uuid . '.png'));
        $this->assertSame($pngData, file_get_contents(storage_path('app/public/vm-previews/' . $uuid . '.png')));
    }

    public function test_capture_preview_client_error_returns_error_message(): void
    {
        $vm = VirtualMachine::create([
            'user_id' => $this->user->id,
            'name' => 'Test VM',
            'vm_id' => (string) Str::uuid(),
            'uuid' => (string) Str::uuid(),
            'status' => 'running',
            'vnc_port' => 5901,
        ]);

        Http::fake([
            self::SERVICE_URL . '/preview' => Http::response(
                ['success' => false, 'error_message' => 'VM not found'],
                200,
                ['Content-Type' => 'application/json']
            ),
        ]);

        $service = new QemuService();
        $result = $service->capturePreview($vm);

        $this->assertNull($result['url']);
        $this->assertSame('VM not found', $result['error_message']);
    }
}
