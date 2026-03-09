<?php

namespace App\Providers;

use App\Models\VirtualMachine;
use App\Policies\VirtualMachinePolicy;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    protected $policies = [
        VirtualMachine::class => VirtualMachinePolicy::class,
    ];

    public function boot(): void
    {
        $this->registerPolicies();
    }
}
