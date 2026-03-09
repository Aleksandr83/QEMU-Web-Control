<?php

use App\Models\VirtualMachine;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote')->hourly();

Artisan::command('vnc:diagnostics', function () {
    $this->info('=== VNC Diagnostics ===');
    $tokenPath = storage_path('app/vnc-tokens.txt');
    $this->line("Token file: {$tokenPath}");
    if (is_file($tokenPath)) {
        $content = file_get_contents($tokenPath);
        $this->info('  ✓ File exists');
        if (trim($content) !== '') {
            $this->line('  Tokens: ' . trim($content));
        } else {
            $this->warn('  ⚠ File is empty');
        }
    } else {
        $this->error('  ✗ File not found');
    }
    $this->line("\nVNC host: " . config('qemu.vnc_host', '127.0.0.1'));
    $running = VirtualMachine::where('status', 'running')->get();
    $this->line("\nRunning VMs: " . $running->count());
    foreach ($running as $vm) {
        $this->line("  - {$vm->name} (id={$vm->id}, vnc_port={$vm->vnc_port})");
    }
    $this->line("\nManual: docker compose exec app ss -tlnp | grep -E '6080|5900'");
})->purpose('Check VNC/WebSocket connectivity');

Schedule::command('cache:prune-stale-tags')->hourly();
Schedule::command('vm:sync-status')->everyMinute();
