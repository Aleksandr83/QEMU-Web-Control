<?php

namespace App\Console\Commands;

use App\Models\VirtualMachine;
use App\Services\QemuService;
use Illuminate\Console\Command;

class AutostartVirtualMachines extends Command
{
    protected $signature = 'vm:autostart';
    protected $description = 'Start all virtual machines marked for autostart';

    public function __construct(private QemuService $qemuService)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $this->info('Starting virtual machines marked for autostart...');
        
        $vms = VirtualMachine::where('autostart', true)
            ->where('status', 'stopped')
            ->get();

        if ($vms->isEmpty()) {
            $this->info('No virtual machines marked for autostart.');
            return self::SUCCESS;
        }

        $started = 0;
        $failed = 0;

        foreach ($vms as $vm) {
            $this->info("Starting VM: {$vm->name}...");
            
            if ($this->qemuService->start($vm)) {
                $this->info("✓ {$vm->name} started successfully");
                $started++;
            } else {
                $this->error("✗ Failed to start {$vm->name}");
                $failed++;
            }
        }

        $this->newLine();
        $this->info("Started: {$started}, Failed: {$failed}");

        return self::SUCCESS;
    }
}
