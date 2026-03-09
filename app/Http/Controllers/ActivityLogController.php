<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\InfoLog;
use App\Models\VirtualMachine;
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
        if (!in_array($tab, ['activity', 'errors', 'info'], true)) {
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

        return response()
            ->view('activity-logs.index', compact('logs', 'tab', 'errorLogs', 'infoLogs', 'operationTypeFilter'))
            ->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
    }

    public function clear(Request $request): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        $tab = $request->input('tab', 'activity');
        if (!in_array($tab, ['activity', 'errors', 'info'], true)) {
            return redirect()->route('activity-logs.index', ['tab' => $tab]);
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

    public function clearAll(Request $request): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);
        ActivityLog::query()->delete();
        InfoLog::query()->delete();
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
