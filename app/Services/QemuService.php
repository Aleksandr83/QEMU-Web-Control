<?php

namespace App\Services;

use App\Models\VirtualMachine;
use App\Models\ActivityLog;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;

class QemuService
{
    private string $qemuImg;
    private string $vmStorage;
    private string $defaultArchitecture;
    private string $previewStorage;
    private ?string $lastError = null;

    public function __construct()
    {
        $this->qemuImg = config('qemu.img_path', '/usr/bin/qemu-img');
        $this->vmStorage = config('qemu.vm_storage', '/var/lib/qemu/vms');
        $this->defaultArchitecture = config('qemu.default_architecture', 'x86_64');
        $this->previewStorage = storage_path('app/public/vm-previews');
    }

    public function createDisk(VirtualMachine $vm): bool
    {
        try {
            foreach ($this->getDiskDefinitions($vm) as $disk) {
                if (file_exists($disk['path'])) {
                    continue;
                }

                $diskDir = dirname($disk['path']);
                if (!is_dir($diskDir)) {
                    mkdir($diskDir, 0755, true);
                }

                $process = new Process([
                    $this->qemuImg,
                    'create',
                    '-f', 'qcow2',
                    $disk['path'],
                    $disk['size_gb'] . 'G'
                ]);
                $process->run();

                if (!$process->isSuccessful()) {
                    $message = 'Failed to create disk: ' . trim($process->getErrorOutput());
                    $this->setLastError($message);
                    Log::error($message, ['path' => $disk['path']]);
                    return false;
                }
            }

            return true;
        } catch (\Exception $e) {
            $message = 'Disk creation error: ' . $e->getMessage();
            $this->setLastError($message);
            Log::error($message);
            return false;
        }
    }

    public function start(VirtualMachine $vm): bool
    {
        $this->lastError = null;
        try {
            if ($vm->isRunning()) {
                return $this->failStart($vm, 'VM is already running');
            }

            if (!$this->createDisk($vm)) {
                return $this->failStart($vm, $this->lastError ?: 'Failed to create disk');
            }

            return $this->startViaExternalService($vm);
        } catch (\Exception $e) {
            $message = 'VM start error: ' . $e->getMessage();
            return $this->failStart($vm, $message);
        }
    }

    public function stop(VirtualMachine $vm): bool
    {
        try {
            if (!$vm->isRunning() || !$vm->pid) {
                return false;
            }

            return $this->stopViaExternalService($vm);
        } catch (\Exception $e) {
            Log::error('VM stop error: ' . $e->getMessage());
            return false;
        }
    }

    public function restart(VirtualMachine $vm): bool
    {
        if (!$this->stop($vm)) {
            return false;
        }

        sleep(2);

        if ($this->start($vm)) {
            ActivityLog::logVm(ActivityLog::ACTION_RESTART, $vm);
            return true;
        }

        return false;
    }

    public function checkStatus(VirtualMachine $vm): string
    {
        if (!$vm->pid) {
            return 'stopped';
        }

        return $this->checkStatusViaExternalService($vm);
    }

    public function syncRunningVmsStatus(): void
    {
        $runningVms = VirtualMachine::where('status', 'running')->get();
        foreach ($runningVms as $vm) {
            if (!$vm->pid) {
                $vm->update([
                    'status' => 'stopped',
                    'pid' => null,
                    'last_stopped_at' => now(),
                ]);
                continue;
            }
            $actual = $this->checkStatus($vm);
            if ($actual === 'stopped') {
                $vm->update([
                    'status' => 'error',
                    'pid' => null,
                    'last_stopped_at' => now(),
                ]);
                ActivityLog::logVmError($vm, 'Process not running (sync)', ActivityLog::ACTION_START_FAILED, []);
            }
        }

        VirtualMachine::where('status', 'error')->whereNull('pid')->update([
            'status' => 'stopped',
            'last_stopped_at' => now(),
        ]);
    }

    private function startViaExternalService(VirtualMachine $vm): bool
    {
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $disks = $this->getDiskDefinitions($vm);
        $primary = $disks[0] ?? null;
        if (!$primary) {
            return $this->failStart($vm, 'No disk definition');
        }

        $params = [
            'vm_id' => $vm->vm_id,
            'architecture' => $vm->architecture ?: $this->defaultArchitecture,
            'cpu_cores' => $vm->cpu_cores,
            'ram_mb' => $vm->ram_mb,
            'primary_disk_path' => $primary['path'],
            'additional_disks' => array_slice(array_column($disks, 'path'), 1),
            'iso_path' => $vm->iso_path ?? '',
            'enable_kvm' => (bool) ($vm->enable_kvm ?? true),
            'network_type' => $vm->network_type ?? 'user',
            'vnc_port' => $vm->vnc_port ?? 0,
            'mac_address' => $vm->mac_address ?? '',
            'qmp_socket_path' => $this->qmpSocketPath($vm),
        ];

        $result = $client->startVm($params);
        if (!$result || !($result['success'] ?? false)) {
            $errMsg = $result['error_message'] ?? 'External QEMU service failed';
            if ($errMsg === 'VM already running' && ($vm->status === 'error' || $vm->status === 'stopped')) {
                $client->stopVm($vm->vm_id, $vm->pid ?? 0);
                sleep(2);
                $result = $client->startVm($params);
            }
            if (!$result || !($result['success'] ?? false)) {
                return $this->failStart($vm, $result['error_message'] ?? $errMsg);
            }
        }

        $pid = (int) ($result['pid'] ?? 0);
        if ($pid <= 0) {
            return $this->failStart($vm, 'External service did not return valid PID');
        }

        $vm->update([
            'status' => 'running',
            'pid' => $pid,
            'last_started_at' => now(),
        ]);

        ActivityLog::logVm(ActivityLog::ACTION_START, $vm);
        return true;
    }

    private function stopViaExternalService(VirtualMachine $vm): bool
    {
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $result = $client->stopVm($vm->vm_id, $vm->pid);
        if (!$result || !($result['success'] ?? false)) {
            Log::warning('External QEMU stop failed', ['vm_id' => $vm->id, 'result' => $result]);
        }

        $vm->update([
            'status' => 'stopped',
            'pid' => null,
            'last_stopped_at' => now(),
        ]);

        ActivityLog::logVm(ActivityLog::ACTION_STOP, $vm);
        return true;
    }

    public function sendTextToVm(VirtualMachine $vm, string $text, string $keyboardLayout = ''): array
    {
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $result = $client->sendText($vm->vm_id, $vm->uuid ?? null, $text, $keyboardLayout);
        if (!$result) {
            return ['success' => false, 'error_message' => 'External QEMU service failed'];
        }
        return [
            'success' => (bool) ($result['success'] ?? false),
            'error_message' => $result['error_message'] ?? null,
        ];
    }

    private function checkStatusViaExternalService(VirtualMachine $vm): string
    {
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $result = $client->getStatus($vm->vm_id);
        if (!$result) {
            return 'stopped';
        }
        return ($result['running'] ?? false) ? 'running' : 'stopped';
    }

    public function deleteDisk(VirtualMachine $vm): bool
    {
        $deleted = true;
        foreach ($this->getDiskDefinitions($vm) as $disk) {
            if (file_exists($disk['path']) && !unlink($disk['path'])) {
                $deleted = false;
            }
        }
        return $deleted;
    }

    private function getDiskDefinitions(VirtualMachine $vm): array
    {
        try {
            $diskModels = $vm->disks()->orderBy('boot_order')->get();
            if ($diskModels->isNotEmpty()) {
                return $diskModels->map(static function ($disk) {
                    return [
                        'path' => $disk->path,
                        'size_gb' => (int) $disk->size_gb,
                        'interface' => $disk->interface ?: 'virtio',
                    ];
                })->all();
            }
        } catch (\Throwable $e) {
            Log::warning('Failed to read VM disks relation, using legacy fields', [
                'vm_id' => $vm->id,
                'error' => $e->getMessage(),
            ]);
        }

        $legacyPath = $vm->disk_path ?: ($this->vmStorage . '/' . $vm->uuid . '.qcow2');
        return [[
            'path' => $legacyPath,
            'size_gb' => (int) ($vm->disk_size_gb ?: 20),
            'interface' => 'virtio',
        ]];
    }

    public function capturePreview(VirtualMachine $vm): array
    {
        if (!$vm->isRunning() || !$vm->vnc_port) {
            return ['url' => null, 'error_message' => null];
        }

        if (!config('qemu.use_external_qemu', true)) {
            return ['url' => null, 'error_message' => null];
        }

        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $vmId = $vm->vm_id ?? '';
        Log::info('QemuService capturePreview', ['vm_id' => $vmId, 'uuid' => $vm->uuid]);
        $result = $client->capturePreview($vmId, $vm->uuid ?? null);
        if ($result['data'] === null) {
            Log::warning('QemuService capturePreview failed', ['vm_id' => $vmId, 'error' => $result['error_message']]);
            return ['url' => null, 'error_message' => $result['error_message']];
        }

        if (!is_dir($this->previewStorage)) {
            mkdir($this->previewStorage, 0755, true);
        }
        $previewPath = $this->previewStorage . '/' . $vm->uuid . '.png';
        if (file_put_contents($previewPath, $result['data']) === false) {
            return ['url' => null, 'error_message' => 'Failed to save preview'];
        }

        return ['url' => 'storage/vm-previews/' . $vm->uuid . '.png', 'error_message' => null];
    }

    private function qmpSocketPath(VirtualMachine $vm): string
    {
        $dir = rtrim(config('qemu.qmp_socket_dir', '/var/qemu/qmp'), '/');
        return $dir . '/qemu-' . $vm->uuid . '.qmp';
    }

    public function lastError(): ?string
    {
        return $this->lastError;
    }

    private function setLastError(string $message): void
    {
        $this->lastError = trim($message);
    }

    private function failStart(VirtualMachine $vm, string $message, array $details = []): bool
    {
        $this->setLastError($message);
        Log::error($message, array_merge(['vm_id' => $vm->id], $details));
        ActivityLog::logVmError($vm, $message, ActivityLog::ACTION_START_FAILED, $details);
        $vm->update([
            'status' => 'error',
            'pid' => null,
            'last_stopped_at' => now(),
        ]);

        return false;
    }
}
