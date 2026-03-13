<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\InfoLog;
use App\Models\VirtualMachine;
use App\Services\QemuControlServiceClient;
use App\Services\QemuService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class ActivityLogController extends Controller
{
    public function index(Request $request): Response
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $tab = $request->query('tab', 'activity');
        if (!in_array($tab, ['activity', 'errors', 'info', 'service'], true)) {
            $tab = 'activity';
        }

        $logs = null;
        if ($tab === 'activity') {
            $logs = ActivityLog::with('user')
                ->where('type', '!=', ActivityLog::TYPE_ERROR)
                ->latest()
                ->paginate(15)
                ->withQueryString();
        }

        $errorLogs = $tab === 'errors'
            ? ActivityLog::with('user')
                ->where('type', ActivityLog::TYPE_ERROR)
                ->latest()
                ->paginate(15)
                ->withQueryString()
            : null;

        $operationTypeFilter = $request->query('operation_type');
        $infoLogs = $tab === 'info'
            ? InfoLog::when($operationTypeFilter, fn ($q) => $q->where('operation_type', $operationTypeFilter))
                ->latest()
                ->paginate(15)
                ->withQueryString()
            : null;

        $serviceLogs = null;
        $serviceLogsError = null;
        if ($tab === 'service') {
            $limit = min(max((int) $request->query('limit', 500), 1), 5000);
            $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
            $data = $client->getLogs($limit);
            if ($data !== null) {
                $serviceLogs = $data['lines'] ?? [];
            } else {
                $serviceLogsError = __('ui.logs_service_unavailable');
            }
        }

        return response()
            ->view('activity-logs.index', compact('logs', 'tab', 'errorLogs', 'infoLogs', 'operationTypeFilter', 'serviceLogs', 'serviceLogsError'))
            ->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    }

    public function clear(Request $request): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        $tab = $request->input('tab', 'activity');
        if (!in_array($tab, ['activity', 'errors', 'info', 'service'], true)) {
            return redirect()->route('activity-logs.index', ['tab' => $tab]);
        }
        if ($tab === 'service') {
            return redirect()->route('activity-logs.index', ['tab' => 'service']);
        }
        if ($tab === 'activity') {
            ActivityLog::where('type', '!=', ActivityLog::TYPE_ERROR)->delete();
        } elseif ($tab === 'errors') {
            ActivityLog::where('type', ActivityLog::TYPE_ERROR)->delete();
        } else {
            $operationType = $request->input('operation_type');
            $q = InfoLog::query();
            if ($operationType) {
                $q->where('operation_type', $operationType);
            }
            $q->delete();
        }
        return redirect()->route('activity-logs.index', array_filter(['tab' => $tab, 'operation_type' => $request->input('operation_type')]))->with('success', __('ui.logs_cleared'));
    }

    public function clearServiceLog(): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        if ($client->clearServiceLog()) {
            return redirect()->route('activity-logs.index', ['tab' => 'service'])->with('success', __('ui.logs_cleared'));
        }
        return redirect()->route('activity-logs.index', ['tab' => 'service'])->with('error', __('ui.logs_service_unavailable'));
    }

    public function clearAll(Request $request): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        ActivityLog::query()->delete();
        InfoLog::query()->delete();
        $client = new QemuControlServiceClient(config('qemu.qemu_control_service_url'));
        $client->clearServiceLog();
        return redirect()->route('activity-logs.index', ['tab' => $request->input('tab', 'activity')])->with('success', __('ui.logs_cleared_all'));
    }

    public function triggerPreview(QemuService $qemuService): JsonResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        $vms = VirtualMachine::where('status', 'running')
            ->whereNotNull('vnc_port')
            ->where('vnc_port', '>', 0)
            ->get();
        $count = 0;
        foreach ($vms as $vm) {
            $qemuService->capturePreview($vm);
            $count++;
        }
        return response()->json(['count' => $count]);
    }
}
