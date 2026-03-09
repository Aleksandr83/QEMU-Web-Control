<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\UserVmPermissions;
use App\Models\VirtualMachine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class VirtualMachineControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $owner;

    private User $sharedUserWithEdit;

    private User $sharedUserWithDeleteOnly;

    private User $otherUser;

    private VirtualMachine $vm;

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

        $this->admin = User::create([
            'name' => 'Admin',
            'email' => 'admin@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->admin->roles()->attach($adminRole->id);

        $this->owner = User::create([
            'name' => 'Owner',
            'email' => 'owner@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->owner->roles()->attach($userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->owner->id,
            'can_create_vm' => true,
            'can_delete_vm' => true,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => false,
        ]);

        $this->sharedUserWithEdit = User::create([
            'name' => 'SharedEdit',
            'email' => 'shared-edit@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->sharedUserWithEdit->roles()->attach($userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->sharedUserWithEdit->id,
            'can_create_vm' => false,
            'can_delete_vm' => false,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => true,
            'can_delete_others_vm' => false,
        ]);

        $this->sharedUserWithDeleteOnly = User::create([
            'name' => 'SharedDelete',
            'email' => 'shared-delete@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->sharedUserWithDeleteOnly->roles()->attach($userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->sharedUserWithDeleteOnly->id,
            'can_create_vm' => false,
            'can_delete_vm' => false,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => true,
        ]);

        $this->otherUser = User::create([
            'name' => 'Other',
            'email' => 'other@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->otherUser->roles()->attach($userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->otherUser->id,
            'can_create_vm' => false,
            'can_delete_vm' => false,
            'can_start_vm' => false,
            'can_stop_vm' => false,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => false,
        ]);

        $this->vm = VirtualMachine::create([
            'user_id' => $this->owner->id,
            'name' => 'Test VM',
            'vm_id' => (string) Str::uuid(),
            'cpu_cores' => 2,
            'ram_mb' => 2048,
            'status' => 'stopped',
            'shared_with_all' => false,
        ]);
    }

    public function test_owner_can_access_edit_page(): void
    {
        $response = $this->actingAs($this->owner)->get(route('vms.edit', $this->vm));

        $response->assertStatus(200);
        $response->assertSee($this->vm->name);
    }

    public function test_admin_can_access_edit_page(): void
    {
        $response = $this->actingAs($this->admin)->get(route('vms.edit', $this->vm));

        $response->assertStatus(200);
    }

    public function test_shared_user_with_edit_can_access_edit_page(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUserWithEdit->id);

        $response = $this->actingAs($this->sharedUserWithEdit)->get(route('vms.edit', $this->vm));

        $response->assertStatus(200);
    }

    public function test_shared_user_with_delete_only_can_access_edit_page(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUserWithDeleteOnly->id);

        $response = $this->actingAs($this->sharedUserWithDeleteOnly)->get(route('vms.edit', $this->vm));

        $response->assertStatus(200);
    }

    public function test_other_user_without_access_gets_403(): void
    {
        $response = $this->actingAs($this->otherUser)->get(route('vms.edit', $this->vm));

        $response->assertStatus(403);
    }

    public function test_owner_can_update_vm(): void
    {
        $response = $this->actingAs($this->owner)->put(route('vms.update', $this->vm), [
            '_token' => csrf_token(),
            'name' => 'Updated VM',
            'description' => 'Updated desc',
            'cpu_cores' => 4,
            'ram_mb' => 4096,
            'primary_disk_size_gb' => 20,
            'primary_disk_path' => '',
            'os_type' => '',
            'architecture' => 'x86_64',
            'network_type' => 'user',
            'vnc_port' => '',
            'autostart' => '0',
            'use_audio' => '0',
        ]);

        $response->assertRedirect(route('vms.index'));
        $this->vm->refresh();
        $this->assertSame('Updated VM', $this->vm->name);
        $this->assertSame(4, $this->vm->cpu_cores);
    }

    public function test_other_user_cannot_update_vm(): void
    {
        $response = $this->actingAs($this->otherUser)->put(route('vms.update', $this->vm), [
            '_token' => csrf_token(),
            'name' => 'Hacked',
            'description' => '',
            'cpu_cores' => 2,
            'ram_mb' => 2048,
            'primary_disk_size_gb' => 20,
            'primary_disk_path' => '',
            'os_type' => '',
            'architecture' => 'x86_64',
            'network_type' => 'user',
            'vnc_port' => '',
            'autostart' => '0',
            'use_audio' => '0',
        ]);

        $response->assertStatus(403);
        $this->vm->refresh();
        $this->assertSame('Test VM', $this->vm->name);
    }
}
