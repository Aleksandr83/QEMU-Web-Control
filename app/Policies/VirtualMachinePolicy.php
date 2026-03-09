<?php

namespace App\Policies;

use App\Models\User;
use App\Models\VirtualMachine;

class VirtualMachinePolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, VirtualMachine $vm): bool
    {
        return $vm->hasAccess($user);
    }

    public function create(User $user): bool
    {
        return $user->canCreateVm();
    }

    public function update(User $user, VirtualMachine $vm): bool
    {
        if ($user->isAdmin() || $vm->user_id === $user->id) {
            return true;
        }
        return $vm->hasAccess($user) && $user->canEditOthersVm();
    }

    public function delete(User $user, VirtualMachine $vm): bool
    {
        if ($user->isAdmin()) {
            return true;
        }
        if ($vm->user_id === $user->id) {
            return $user->canDeleteVm();
        }
        return $vm->hasAccess($user) && $user->canDeleteOthersVm();
    }

    public function start(User $user, VirtualMachine $vm): bool
    {
        return $vm->hasAccess($user) && $user->canStartVm();
    }

    public function stop(User $user, VirtualMachine $vm): bool
    {
        return $vm->hasAccess($user) && $user->canStopVm();
    }

}
