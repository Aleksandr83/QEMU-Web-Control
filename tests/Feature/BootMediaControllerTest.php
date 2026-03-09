<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class BootMediaControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $adminUser;

    private User $regularUser;

    private string $stagingDir;

    private string $uploadDir;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::create([
            'slug' => 'administrator',
            'name' => 'Administrator',
            'description' => 'Admin',
            'color' => '#ef4444',
            'is_system' => true,
        ]);

        $userRole = Role::create([
            'slug' => 'user',
            'name' => 'User',
            'description' => 'User',
            'color' => '#3b82f6',
            'is_system' => true,
        ]);

        $this->adminUser = User::create([
            'name' => 'Admin',
            'email' => 'admin@test.local',
            'password' => Hash::make('password'),
        ]);
        $this->adminUser->roles()->attach($adminRole->id);

        $this->regularUser = User::create([
            'name' => 'User',
            'email' => 'user@test.local',
            'password' => Hash::make('password'),
        ]);
        $this->regularUser->roles()->attach($userRole->id);

        $this->stagingDir = sys_get_temp_dir() . '/boot-media-test-staging-' . uniqid();
        $this->uploadDir = sys_get_temp_dir() . '/boot-media-test-upload-' . uniqid();
        mkdir($this->stagingDir, 0755, true);
        mkdir($this->uploadDir, 0755, true);
    }

    protected function tearDown(): void
    {
        if (is_dir($this->stagingDir)) {
            array_map('unlink', glob($this->stagingDir . '/*') ?: []);
            rmdir($this->stagingDir);
        }
        if (is_dir($this->uploadDir)) {
            array_map('unlink', glob($this->uploadDir . '/*') ?: []);
            rmdir($this->uploadDir);
        }
        parent::tearDown();
    }

    public function test_index_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->get(route('boot-media.index'));

        $response->assertStatus(403);
    }

    public function test_index_returns_200_for_admin(): void
    {
        Config::set('qemu.iso_upload_staging', $this->stagingDir);
        Config::set('qemu.iso_directories', [$this->uploadDir]);
        Config::set('qemu.iso_upload_directories', [$this->uploadDir]);
        Config::set('qemu.boot_media_service_url', 'http://localhost:50052');

        $response = $this->actingAs($this->adminUser)->get(route('boot-media.index'));

        $response->assertStatus(200);
    }

    public function test_store_returns_403_for_non_admin(): void
    {
        $file = UploadedFile::fake()->create('test.iso', 100);

        $response = $this->actingAs($this->regularUser)->post(route('boot-media.store'), [
            'iso' => $file,
            'target_dir' => $this->uploadDir,
        ]);

        $response->assertStatus(403);
    }

    public function test_store_returns_403_for_invalid_target_dir(): void
    {
        Config::set('qemu.iso_upload_staging', $this->stagingDir);
        Config::set('qemu.iso_directories', [$this->uploadDir]);
        Config::set('qemu.iso_upload_directories', [$this->uploadDir]);
        Config::set('qemu.boot_media_service_url', 'http://localhost:50052');

        $file = UploadedFile::fake()->create('test.iso', 100);

        $response = $this->actingAs($this->adminUser)->post(route('boot-media.store'), [
            'iso' => $file,
            'target_dir' => '/tmp/invalid-path-not-in-allowed',
        ]);

        $response->assertStatus(403);
    }

    public function test_store_success_with_move_iso(): void
    {
        Config::set('qemu.iso_upload_staging', $this->stagingDir);
        Config::set('qemu.iso_directories', [$this->uploadDir]);
        Config::set('qemu.iso_upload_directories', [$this->uploadDir]);
        Config::set('qemu.boot_media_service_url', 'http://localhost:50052');

        Http::fake([
            'http://localhost:50052/move' => Http::response([
                'operation_id' => 'op-123',
            ], 200),
        ]);

        $file = UploadedFile::fake()->createWithContent('test.iso', str_repeat('x', 1024));

        $response = $this->actingAs($this->adminUser)->post(route('boot-media.store'), [
            'iso' => $file,
            'target_dir' => $this->uploadDir,
        ]);

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);
        $response->assertJsonStructure(['operation_id', 'filename', 'target_dir', 'path']);
    }

    public function test_store_fallback_to_php_move_when_service_unavailable(): void
    {
        Config::set('qemu.iso_upload_staging', $this->stagingDir);
        Config::set('qemu.iso_directories', [$this->uploadDir]);
        Config::set('qemu.iso_upload_directories', [$this->uploadDir]);
        Config::set('qemu.boot_media_service_url', 'http://localhost:50052');

        Http::fake([
            'http://localhost:50052/move' => function () {
                throw new \Exception('Connection refused');
            },
        ]);

        $file = UploadedFile::fake()->createWithContent('test.iso', str_repeat('x', 1024));

        $response = $this->actingAs($this->adminUser)->post(route('boot-media.store'), [
            'iso' => $file,
            'target_dir' => $this->uploadDir,
        ]);

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);
        $this->assertFileExists($this->uploadDir . '/test.iso');
    }

    public function test_progress_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->get(route('boot-media.progress', ['operationId' => 'op-1']));

        $response->assertStatus(403);
    }

    public function test_progress_returns_200_for_admin(): void
    {
        Config::set('qemu.boot_media_service_url', 'http://localhost:50052');

        Http::fake([
            'http://localhost:50052/progress/op-1' => Http::response([
                'operation_id' => 'op-1',
                'status' => 'running',
                'progress' => 50,
            ], 200),
        ]);

        $response = $this->actingAs($this->adminUser)->get(route('boot-media.progress', ['operationId' => 'op-1']));

        $response->assertStatus(200);
        $response->assertJson(['status' => 'running', 'progress' => 50]);
    }

    public function test_cancel_move_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->post(route('boot-media.cancel'), [
            'operation_id' => 'op-1',
        ]);

        $response->assertStatus(403);
    }

    public function test_destroy_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->delete(route('boot-media.destroy'), [
            'paths' => ['/srv/iso/test.iso'],
        ]);

        $response->assertStatus(403);
    }

    public function test_download_returns_403_for_non_admin(): void
    {
        $encoded = base64_encode(strtr($this->uploadDir . '/test.iso', '+/', '-_'));
        $response = $this->actingAs($this->regularUser)->get(route('boot-media.download', ['f' => $encoded]));

        $response->assertStatus(403);
    }
}
