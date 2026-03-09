<?php

namespace Tests\Feature;

use App\Models\Group;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class GroupControllerTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $regularUser;

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

        $this->regularUser = User::create([
            'name' => 'User',
            'email' => 'user@test.local',
            'password' => bcrypt('password'),
        ]);
        $this->regularUser->roles()->attach($userRole->id);
    }

    public function test_index_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->get(route('groups.index'));

        $response->assertStatus(403);
    }

    public function test_index_returns_200_for_admin(): void
    {
        $response = $this->actingAs($this->admin)->get(route('groups.index'));

        $response->assertStatus(200);
    }

    public function test_create_returns_403_for_non_admin(): void
    {
        $response = $this->actingAs($this->regularUser)->get(route('groups.create'));

        $response->assertStatus(403);
    }

    public function test_store_creates_group(): void
    {
        $response = $this->actingAs($this->admin)->post(route('groups.store'), [
            'name' => 'Developers',
        ]);

        $response->assertRedirect(route('groups.index'));
        $this->assertDatabaseHas('groups', [
            'name' => 'Developers',
            'slug' => 'developers',
        ]);
    }

    public function test_edit_returns_403_for_non_admin(): void
    {
        $group = Group::create(['name' => 'Team', 'slug' => 'team']);

        $response = $this->actingAs($this->regularUser)->get(route('groups.edit', $group));

        $response->assertStatus(403);
    }

    public function test_update_modifies_group_and_members(): void
    {
        $group = Group::create(['name' => 'Team', 'slug' => 'team']);

        $response = $this->actingAs($this->admin)->put(route('groups.update', $group), [
            'name' => 'Updated Team',
            'user_ids' => [$this->regularUser->id],
        ]);

        $response->assertRedirect(route('groups.index'));
        $group->refresh();
        $this->assertSame('Updated Team', $group->name);
        $this->assertCount(1, $group->users);
        $this->assertTrue($group->users->contains($this->regularUser));
    }

    public function test_destroy_deletes_group(): void
    {
        $group = Group::create(['name' => 'ToDelete', 'slug' => 'todelete']);

        $response = $this->actingAs($this->admin)->delete(route('groups.destroy', $group));

        $response->assertRedirect(route('groups.index'));
        $this->assertDatabaseMissing('groups', ['id' => $group->id]);
    }

    public function test_destroy_returns_403_for_non_admin(): void
    {
        $group = Group::create(['name' => 'Team', 'slug' => 'team']);

        $response = $this->actingAs($this->regularUser)->delete(route('groups.destroy', $group));

        $response->assertStatus(403);
    }
}
