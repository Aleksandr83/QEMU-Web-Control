<?php

namespace App\Services;

use App\Models\VirtualMachine;
use Illuminate\Support\Str;

class VncTokenService
{
    private string $tokenFilePath;

    public function __construct()
    {
        $this->tokenFilePath = storage_path('app/vnc-tokens.txt');
    }

    public function createToken(VirtualMachine $vm): ?string
    {
        if (!$vm->isRunning() || !$vm->vnc_port) {
            return null;
        }

        $vncHost = config('qemu.vnc_host_for_tokens') ?: (config('qemu.vnc_proxy_via_qemu_control') ? '127.0.0.1' : config('qemu.vnc_host', '127.0.0.1'));
        $token = 'vctx_' . $vm->id . '_' . Str::random(12);
        $line = $token . ': ' . $vncHost . ':' . $vm->vnc_port . "\n";

        $dir = dirname($this->tokenFilePath);
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }

        $prefix = 'vctx_' . $vm->id . '_';
        $content = is_file($this->tokenFilePath)
            ? file_get_contents($this->tokenFilePath)
            : '';
        $lines = array_filter(
            explode("\n", $content),
            fn (string $l) => $l !== '' && !str_starts_with(trim($l), $prefix)
        );
        $lines[] = trim($line);
        file_put_contents($this->tokenFilePath, implode("\n", $lines) . "\n", LOCK_EX);

        return $token;
    }
}
