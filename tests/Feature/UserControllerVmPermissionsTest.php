<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\UserVmPermissions;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserControllerVmPermissionsTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

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
    }

    public function test_store_creates_user_with_vm_permissions(): void
    {
        $userRole = Role::where('slug', 'user')->first();

        $response = $this->actingAs($this->admin)->post(route('users.store'), [
            'name' => 'New User',
            'email' => 'new@test.local',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role_id' => $userRole->id,
            'can_create_vm' => '1',
            'can_delete_vm' => '0',
            'can_start_vm' => '1',
            'can_stop_vm' => '0',
            'can_edit_others_vm' => '1',
            'can_delete_others_vm' => '0',
        ]);

        $response->assertRedirect(route('users.index'));

        $user = User::where('email', 'new@test.local')->first();
        $this->assertNotNull($user);

        $perms = $user->vmPermissions;
        $this->assertNotNull($perms);
        $this->assertTrue($perms->can_create_vm);
        $this->assertFalse($perms->can_delete_vm);
        $this->assertTrue($perms->can_start_vm);
        $this->assertFalse($perms->can_stop_vm);
        $this->assertTrue($perms->can_edit_others_vm);
        $this->assertFalse($perms->can_delete_others_vm);
    }

    public function test_update_saves_vm_permissions(): void
    {
        $userRole = Role::where('slug', 'user')->first();
        $user = User::create([
            'name' => 'Test User',
            'email' => 'test@test.local',
            'password' => bcrypt('password'),
        ]);
        $user->roles()->attach($userRole->id);
        UserVmPermissions::create([
            'user_id' => $user->id,
            'can_create_vm' => true,
            'can_delete_vm' => true,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => false,
        ]);

        $response = $this->actingAs($this->admin)->put(route('users.update', $user), [
            '_token' => csrf_token(),
            '_method' => 'PUT',
            'name' => 'Test User',
            'email' => 'test@test.local',
            'role_id' => $userRole->id,
            'password' => '',
            'password_confirmation' => '',
            'can_create_vm' => '0',
            'can_delete_vm' => '1',
            'can_start_vm' => '0',
            'can_stop_vm' => '1',
            'can_edit_others_vm' => '1',
            'can_delete_others_vm' => '1',
        ]);

        $response->assertRedirect(route('users.index'));

        $user->refresh();
        $perms = $user->vmPermissions;
        $this->assertFalse($perms->can_create_vm);
        $this->assertTrue($perms->can_delete_vm);
        $this->assertFalse($perms->can_start_vm);
        $this->assertTrue($perms->can_stop_vm);
        $this->assertTrue($perms->can_edit_others_vm);
        $this->assertTrue($perms->can_delete_others_vm);
    }
}
