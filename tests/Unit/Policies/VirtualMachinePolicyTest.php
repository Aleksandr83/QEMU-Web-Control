<?php

namespace Tests\Unit\Policies;

use App\Models\Group;
use App\Models\Role;
use App\Models\User;
use App\Models\UserVmPermissions;
use App\Models\VirtualMachine;
use App\Policies\VirtualMachinePolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VirtualMachinePolicyTest extends TestCase
{
    use RefreshDatabase;

    private Role $adminRole;

    private Role $userRole;

    private User $admin;

    private User $owner;

    private User $sharedUser;

    private User $otherUser;

    private VirtualMachine $vm;

    protected function setUp(): void
    {
        parent::setUp();

        $this->adminRole = Role::create([
            'slug' => 'administrator',
            'name' => 'Administrator',
            'description' => 'Admin',
            'color' => '#ef4444',
            'is_system' => true,
        ]);

        $this->userRole = Role::create([
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
        $this->admin->roles()->attach($this->adminRole->id);

        $this->owner = User::create([
            'name' => 'Owner',
            'email' => 'owner@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->owner->roles()->attach($this->userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->owner->id,
            'can_create_vm' => true,
            'can_delete_vm' => true,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => false,
        ]);

        $this->sharedUser = User::create([
            'name' => 'Shared',
            'email' => 'shared@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->sharedUser->roles()->attach($this->userRole->id);
        UserVmPermissions::create([
            'user_id' => $this->sharedUser->id,
            'can_create_vm' => false,
            'can_delete_vm' => false,
            'can_start_vm' => true,
            'can_stop_vm' => true,
            'can_edit_others_vm' => false,
            'can_delete_others_vm' => false,
        ]);

        $this->otherUser = User::create([
            'name' => 'Other',
            'email' => 'other@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->otherUser->roles()->attach($this->userRole->id);
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
            'vm_id' => (string) \Illuminate\Support\Str::uuid(),
            'cpu_cores' => 2,
            'ram_mb' => 2048,
            'status' => 'stopped',
            'shared_with_all' => false,
        ]);
    }

    public function test_admin_can_do_anything(): void
    {
        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->view($this->admin, $this->vm));
        $this->assertTrue($policy->update($this->admin, $this->vm));
        $this->assertTrue($policy->delete($this->admin, $this->vm));
        $this->assertTrue($policy->start($this->admin, $this->vm));
        $this->assertTrue($policy->stop($this->admin, $this->vm));
    }

    public function test_owner_can_update_and_delete_own_vm(): void
    {
        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->view($this->owner, $this->vm));
        $this->assertTrue($policy->update($this->owner, $this->vm));
        $this->assertTrue($policy->delete($this->owner, $this->vm));
    }

    public function test_other_user_without_access_cannot_view(): void
    {
        $policy = new VirtualMachinePolicy();

        $this->assertFalse($policy->view($this->otherUser, $this->vm));
        $this->assertFalse($policy->update($this->otherUser, $this->vm));
        $this->assertFalse($policy->delete($this->otherUser, $this->vm));
    }

    public function test_shared_user_with_access_can_view_and_start_stop(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUser->id);

        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->view($this->sharedUser, $this->vm));
        $this->assertTrue($policy->start($this->sharedUser, $this->vm));
        $this->assertTrue($policy->stop($this->sharedUser, $this->vm));
    }

    public function test_shared_user_without_edit_others_cannot_update(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUser->id);

        $policy = new VirtualMachinePolicy();

        $this->assertFalse($policy->update($this->sharedUser, $this->vm));
    }

    public function test_shared_user_with_edit_others_can_update(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUser->id);
        $this->sharedUser->vmPermissions->update(['can_edit_others_vm' => true]);

        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->update($this->sharedUser, $this->vm));
    }

    public function test_shared_user_without_delete_others_cannot_delete(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUser->id);

        $policy = new VirtualMachinePolicy();

        $this->assertFalse($policy->delete($this->sharedUser, $this->vm));
    }

    public function test_shared_user_with_delete_others_can_delete(): void
    {
        $this->vm->sharedUsers()->attach($this->sharedUser->id);
        $this->sharedUser->vmPermissions->update(['can_delete_others_vm' => true]);

        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->delete($this->sharedUser, $this->vm));
    }

    public function test_shared_with_all_grants_view_to_any_user(): void
    {
        $this->vm->update(['shared_with_all' => true]);

        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->view($this->otherUser, $this->vm));
    }

    public function test_user_in_shared_group_can_view(): void
    {
        $group = Group::create(['name' => 'Devs', 'slug' => 'devs']);
        $group->users()->attach($this->otherUser->id);
        $this->vm->sharedGroups()->attach($group->id);

        $policy = new VirtualMachinePolicy();

        $this->assertTrue($policy->view($this->otherUser, $this->vm));
    }
}
