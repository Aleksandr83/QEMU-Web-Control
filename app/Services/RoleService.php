<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;

class RoleService
{
    public static function getAdminRole(): ?Role
    {
        return Role::where('slug', 'administrator')->first();
    }

    public static function getUserRole(): ?Role
    {
        return Role::where('slug', 'user')->first();
    }

    public static function assignAdminRole(User $user): void
    {
        $adminRole = self::getAdminRole();
        $userRole = self::getUserRole();

        if ($adminRole) {
            $user->roles()->syncWithoutDetaching([$adminRole->id]);
        }
        
        if ($userRole) {
            $user->roles()->detach($userRole->id);
        }
    }

    public static function removeAdminRole(User $user): bool
    {
        $adminRole = self::getAdminRole();
        $userRole = self::getUserRole();

        if (!$adminRole) {
            return false;
        }

        $adminCount = User::whereHas('roles', fn($q) => $q->where('role_id', $adminRole->id))->count();
        
        if ($adminCount <= 1) {
            return false;
        }

        $user->roles()->detach($adminRole->id);

        if ($userRole && !$user->roles()->count()) {
            $user->roles()->attach($userRole->id);
        }

        return true;
    }

    public static function assignUserRole(User $user): void
    {
        $adminRole = self::getAdminRole();
        $userRole = self::getUserRole();

        if ($adminRole && $user->roles()->where('role_id', $adminRole->id)->exists()) {
            return;
        }

        if ($userRole) {
            $user->roles()->syncWithoutDetaching([$userRole->id]);
        }
    }
}
