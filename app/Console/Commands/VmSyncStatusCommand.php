<?php

namespace App\Console\Commands;

use App\Models\VirtualMachine;
use App\Services\QemuService;
use Illuminate\Console\Command;

class VmSyncStatusCommand extends Command
{
    protected $signature = 'vm:sync-status';
    protected $description = 'Sync VM status with QemuControlService (mark as stopped if process died)';

    public function __construct(private QemuService $qemuService)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $vms = VirtualMachine::where('status', 'running')->get();
        if ($vms->isEmpty()) {
            return self::SUCCESS;
        }

        $before = $vms->pluck('id')->all();
        $this->qemuService->syncRunningVmsStatus();
        $updated = VirtualMachine::whereIn('id', $before)->where('status', 'error')->get();
        foreach ($updated as $vm) {
            $this->warn("VM {$vm->name} (id={$vm->id}): process died, status set to error");
        }

        return self::SUCCESS;
    }
}
