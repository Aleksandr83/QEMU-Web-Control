<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Models\VirtualMachine;
use App\Services\QemuService;
use Illuminate\Http\JsonResponse;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function index(): View
    {
        app(QemuService::class)->syncRunningVmsStatus();
        $user = auth()->user();

        if ($user->isAdmin()) {
            $vms = VirtualMachine::with('user')->latest()->get();
            $totalVms = VirtualMachine::count();
            $runningVms = VirtualMachine::where('status', 'running')->count();
        } else {
            $vms = VirtualMachine::visibleFor($user)->with('user')->latest()->get();
            $totalVms = $vms->count();
            $runningVms = $vms->where('status', 'running')->count();
        }

        return view('dashboard', compact('vms', 'totalVms', 'runningVms'));
    }

    public function hostMetrics(): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        return response()->json([
            'server_id' => Setting::serverId(),
            'cpu' => $this->collectCpuUsageByCore(),
            'memory' => $this->collectMemoryUsage(),
            'network' => $this->collectNetworkInfo(),
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    private function collectCpuUsageByCore(): array
    {
        $first = $this->readCpuTimes();
        usleep(120000);
        $second = $this->readCpuTimes();

        $result = [];
        foreach ($second as $core => $times) {
            if (!isset($first[$core])) {
                continue;
            }

            $totalDiff = $times['total'] - $first[$core]['total'];
            $idleDiff = $times['idle'] - $first[$core]['idle'];
            $usage = $totalDiff > 0 ? (1 - ($idleDiff / $totalDiff)) * 100 : 0;

            $result[] = [
                'core' => $core,
                'usage_percent' => round(max(0, min(100, $usage)), 1),
            ];
        }

        return $result;
    }

    private function readCpuTimes(): array
    {
        $stat = @file('/proc/stat', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
        $data = [];

        foreach ($stat as $line) {
            if (!preg_match('/^(cpu\d+)\s+(.+)$/', trim($line), $matches)) {
                continue;
            }

            $core = $matches[1];
            $parts = preg_split('/\s+/', trim($matches[2]));
            $parts = array_map('intval', $parts);

            $idle = ($parts[3] ?? 0) + ($parts[4] ?? 0);
            $total = array_sum($parts);

            $data[$core] = [
                'idle' => $idle,
                'total' => $total,
            ];
        }

        return $data;
    }

    private function collectMemoryUsage(): array
    {
        $meminfo = @file('/proc/meminfo', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
        $map = [];
        foreach ($meminfo as $line) {
            if (preg_match('/^([A-Za-z_]+):\s+(\d+)/', $line, $m)) {
                $map[$m[1]] = (int) $m[2];
            }
        }

        $totalKb = (int) ($map['MemTotal'] ?? 0);
        $availableKb = (int) ($map['MemAvailable'] ?? 0);
        $usedKb = max(0, $totalKb - $availableKb);

        return [
            'total_mb' => (int) round($totalKb / 1024),
            'used_mb' => (int) round($usedKb / 1024),
            'free_mb' => (int) round($availableKb / 1024),
            'used_percent' => $totalKb > 0 ? round(($usedKb / $totalKb) * 100, 1) : 0.0,
        ];
    }

    private function collectNetworkInfo(): array
    {
        $port = (int) request()->getPort();
        $host = $this->resolveExternalHost();

        $externalIp = filter_var($host, FILTER_VALIDATE_IP) ? $host : gethostbyname($host);
        if (!filter_var($externalIp, FILTER_VALIDATE_IP)) {
            $externalIp = $host;
        }

        return [
            'external_ip' => $externalIp,
            'internal_ip' => $this->resolveInternalIp(),
            'http_port' => (int) env('APP_PORT', $port > 0 ? $port : 8080),
            'https_port' => (int) env('APP_SSL_PORT', 8443),
        ];
    }

    private function resolveExternalHost(): string
    {
        $appUrl = config('app.url', '');
        if ($appUrl !== '') {
            $parsed = parse_url($appUrl);
            if (is_array($parsed)) {
                $host = $parsed['host'] ?? '';
                if ($host !== '' && !in_array($host, ['localhost', '127.0.0.1'], true)) {
                    return $host;
                }
            }
        }
        return request()->getHost();
    }

    private function resolveInternalIp(): string
    {
        $hostnameIps = trim((string) @shell_exec('hostname -I 2>/dev/null'));
        if ($hostnameIps !== '') {
            $candidates = preg_split('/\s+/', $hostnameIps) ?: [];
            foreach ($candidates as $ip) {
                if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) && $ip !== '127.0.0.1') {
                    return $ip;
                }
            }
        }

        $fallback = gethostbyname(gethostname());
        if (filter_var($fallback, FILTER_VALIDATE_IP) && $fallback !== '127.0.0.1') {
            return $fallback;
        }

        return 'N/A';
    }
}
