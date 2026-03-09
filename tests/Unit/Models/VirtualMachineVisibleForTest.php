<?php

namespace Tests\Unit\Models;

use App\Models\Group;
use App\Models\Role;
use App\Models\User;
use App\Models\UserVmPermissions;
use App\Models\VirtualMachine;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VirtualMachineVisibleForTest extends TestCase
{
    use RefreshDatabase;

    private Role $adminRole;

    private Role $userRole;

    private User $admin;

    private User $user1;

    private User $user2;

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

        $this->user1 = User::create([
            'name' => 'User1',
            'email' => 'user1@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->user1->roles()->attach($this->userRole->id);

        $this->user2 = User::create([
            'name' => 'User2',
            'email' => 'user2@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->user2->roles()->attach($this->userRole->id);
    }

    private function createVm(User $owner, bool $sharedWithAll = false): VirtualMachine
    {
        return VirtualMachine::create([
            'user_id' => $owner->id,
            'name' => 'VM ' . $owner->name,
            'vm_id' => (string) \Illuminate\Support\Str::uuid(),
            'cpu_cores' => 2,
            'ram_mb' => 2048,
            'status' => 'stopped',
            'shared_with_all' => $sharedWithAll,
        ]);
    }

    public function test_admin_sees_all_vms(): void
    {
        $vm1 = $this->createVm($this->user1);
        $vm2 = $this->createVm($this->user2);

        $visible = VirtualMachine::visibleFor($this->admin)->pluck('id')->all();

        $this->assertCount(2, $visible);
        $this->assertContains($vm1->id, $visible);
        $this->assertContains($vm2->id, $visible);
    }

    public function test_user_sees_only_own_vms(): void
    {
        $vm1 = $this->createVm($this->user1);
        $vm2 = $this->createVm($this->user2);

        $visible = VirtualMachine::visibleFor($this->user1)->pluck('id')->all();

        $this->assertCount(1, $visible);
        $this->assertContains($vm1->id, $visible);
        $this->assertNotContains($vm2->id, $visible);
    }

    public function test_user_sees_shared_with_all_vms(): void
    {
        $vm = $this->createVm($this->user2, true);

        $visible = VirtualMachine::visibleFor($this->user1)->pluck('id')->all();

        $this->assertCount(1, $visible);
        $this->assertContains($vm->id, $visible);
    }

    public function test_user_sees_vms_shared_directly(): void
    {
        $vm = $this->createVm($this->user2);
        $vm->sharedUsers()->attach($this->user1->id);

        $visible = VirtualMachine::visibleFor($this->user1)->pluck('id')->all();

        $this->assertCount(1, $visible);
        $this->assertContains($vm->id, $visible);
    }

    public function test_user_sees_vms_shared_via_group(): void
    {
        $group = Group::create(['name' => 'Team', 'slug' => 'team']);
        $group->users()->attach($this->user1->id);

        $vm = $this->createVm($this->user2);
        $vm->sharedGroups()->attach($group->id);

        $visible = VirtualMachine::visibleFor($this->user1)->pluck('id')->all();

        $this->assertCount(1, $visible);
        $this->assertContains($vm->id, $visible);
    }

    public function test_user_without_group_does_not_see_group_shared_vm(): void
    {
        $group = Group::create(['name' => 'Team', 'slug' => 'team']);
        $group->users()->attach($this->user2->id);

        $vm = $this->createVm($this->user2);
        $vm->sharedGroups()->attach($group->id);

        $visible = VirtualMachine::visibleFor($this->user1)->pluck('id')->all();

        $this->assertCount(0, $visible);
    }
}
