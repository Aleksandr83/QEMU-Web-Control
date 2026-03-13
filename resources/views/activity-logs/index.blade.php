<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8" id="activity-logs-container">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.logs') }}</h1>
        </div>

        <div id="activity-logs-content">
        <div class="mb-6 flex flex-wrap items-center gap-3">
            <a
                href="{{ route('activity-logs.index', ['tab' => 'activity']) }}"
                class="px-4 py-2 rounded-lg text-sm font-medium {{ ($tab ?? 'activity') === 'activity' ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all"
            >
                {{ __('ui.logs_activity') }}
            </a>
            <a
                href="{{ route('activity-logs.index', ['tab' => 'errors']) }}"
                class="px-4 py-2 rounded-lg text-sm font-medium {{ ($tab ?? 'activity') === 'errors' ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all"
            >
                {{ __('ui.logs_errors') }}
            </a>
            <a
                href="{{ route('activity-logs.index', array_filter(['tab' => 'info', 'operation_type' => $operationTypeFilter ?? null])) }}"
                class="px-4 py-2 rounded-lg text-sm font-medium {{ ($tab ?? 'activity') === 'info' ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all"
            >
                {{ __('ui.logs_info') }}
            </a>
            <a
                href="{{ route('activity-logs.index', ['tab' => 'service']) }}"
                class="px-4 py-2 rounded-lg text-sm font-medium {{ ($tab ?? 'activity') === 'service' ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all"
            >
                {{ __('ui.logs_service') }}
            </a>
            <div class="ml-auto flex items-center gap-2">
                @if(($tab ?? '') === 'service')
                <form method="POST" action="{{ route('activity-logs.clear-service') }}" class="inline" onsubmit="return confirm('{{ __('ui.logs_clear_confirm') }}');">
                    @csrf
                    <button type="submit" class="px-3 py-1.5 rounded-lg text-sm bg-slate-600 hover:bg-slate-500 text-slate-200 transition-all">
                        {{ __('ui.logs_clear') }}
                    </button>
                </form>
                @else
                <form method="POST" action="{{ route('activity-logs.clear') }}" class="inline" onsubmit="return confirm('{{ __('ui.logs_clear_confirm') }}');">
                    @csrf
                    <input type="hidden" name="tab" value="{{ $tab ?? 'activity' }}">
                    @if(($tab ?? '') === 'info' && !empty($operationTypeFilter))
                        <input type="hidden" name="operation_type" value="{{ $operationTypeFilter }}">
                    @endif
                    <button type="submit" class="px-3 py-1.5 rounded-lg text-sm bg-slate-600 hover:bg-slate-500 text-slate-200 transition-all">
                        {{ __('ui.logs_clear') }}
                    </button>
                </form>
                <form method="POST" action="{{ route('activity-logs.clear-all') }}" class="inline" onsubmit="return confirm('{{ __('ui.logs_clear_all_confirm') }}');">
                    @csrf
                    <input type="hidden" name="tab" value="{{ $tab ?? 'activity' }}">
                    <button type="submit" class="px-3 py-1.5 rounded-lg text-sm bg-amber-600 hover:bg-amber-500 text-white transition-all">
                        {{ __('ui.logs_clear_all') }}
                    </button>
                </form>
                @endif
            </div>
        </div>

        @if(($tab ?? 'activity') === 'activity')
            <div class="card overflow-hidden">
                <div class="overflow-x-auto scrollbar-slate">
                    <table class="min-w-full text-sm">
                        <thead class="bg-slate-800/60 text-slate-300">
                            <tr>
                                <th class="px-4 py-3 text-left">{{ __('ui.created_at') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.users') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.status') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.actions') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.name') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.server_id') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @forelse($logs as $log)
                                <tr class="text-slate-200">
                                    <td class="px-4 py-3">{{ $log->created_at?->format('Y-m-d H:i:s') }}</td>
                                    <td class="px-4 py-3">{{ $log->user?->name ?? '-' }}</td>
                                    <td class="px-4 py-3">{{ strtoupper($log->type) }}</td>
                                    <td class="px-4 py-3">{{ strtoupper($log->action) }}</td>
                                    <td class="px-4 py-3">{{ $log->subject_name ?? '-' }}</td>
                                    <td class="px-4 py-3">{{ $log->server_id ?? '-' }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="6" class="px-4 py-8 text-center text-slate-400">
                                        {{ __('ui.no_activity_logs') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="mt-6">
                {{ $logs?->links('pagination::slate') }}
            </div>
        @elseif(($tab ?? 'activity') === 'errors')
            <div class="card overflow-hidden">
                <div class="overflow-x-auto scrollbar-slate">
                    <table class="min-w-full text-sm">
                        <thead class="bg-slate-800/60 text-slate-300">
                            <tr>
                                <th class="px-4 py-3 text-left">{{ __('ui.created_at') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.users') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.actions') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.name') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.message') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.server_id') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @forelse($errorLogs as $row)
                                <tr class="text-slate-200 align-top">
                                    <td class="px-4 py-3 whitespace-nowrap">{{ $row->created_at?->format('Y-m-d H:i:s') }}</td>
                                    <td class="px-4 py-3">{{ $row->user?->name ?? '-' }}</td>
                                    <td class="px-4 py-3">{{ strtoupper($row->action) }}</td>
                                    <td class="px-4 py-3">{{ $row->subject_name ?? '-' }}</td>
                                    <td class="px-4 py-3 max-w-xs">
                                        @php $errMsg = $row->new_values['message'] ?? null; @endphp
                                        @if($errMsg)
                                            @php $errSingle = preg_replace('/\s+/', ' ', $errMsg); @endphp
                                            <div class="flex items-start gap-1">
                                                <button type="button" class="log-copy-btn shrink-0 p-1 text-slate-400 hover:text-cyan-400 rounded" title="{{ __('ui.logs_copy') }}">
                                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                                </button>
                                                <div class="flex-1 min-w-0">
                                                    <div class="log-collapsible max-w-md min-h-0 scrollbar-slate" data-collapsed="true">
                                                        <span class="log-collapsed-view text-xs bg-slate-800/50 rounded p-2 block truncate">{{ e($errSingle) }}</span>
                                                        <pre class="log-expanded-view hidden text-xs overflow-x-auto whitespace-pre-wrap break-words bg-slate-800/50 rounded p-2 scrollbar-slate">{{ e($errMsg) }}</pre>
                                                    </div>
                                                    <button type="button" class="log-toggle-btn mt-1 text-xs text-slate-400 hover:text-cyan-400">{{ __('ui.logs_expand') }}</button>
                                                </div>
                                            </div>
                                        @else
                                            -
                                        @endif
                                    </td>
                                    <td class="px-4 py-3 whitespace-nowrap">{{ $row->server_id ?? '-' }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="6" class="px-4 py-8 text-center text-slate-400">
                                        {{ __('ui.no_error_logs') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="mt-6">
                {{ $errorLogs?->links('pagination::slate') }}
            </div>
        @elseif(($tab ?? 'activity') === 'info')
            <div class="mb-4 flex flex-wrap items-center gap-3">
                <label for="operation-type-filter" class="text-sm text-slate-400">{{ __('ui.logs_info_operation_type') }}:</label>
                <select id="operation-type-filter" class="input-field w-auto min-w-[140px]" onchange="window.location.href=this.value">
                    <option value="{{ route('activity-logs.index', ['tab' => 'info']) }}" {{ empty($operationTypeFilter) ? 'selected' : '' }}>{{ __('ui.logs_info_filter_all') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'delete']) }}" {{ ($operationTypeFilter ?? '') === 'delete' ? 'selected' : '' }}>{{ __('ui.logs_info_op_delete') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'move']) }}" {{ ($operationTypeFilter ?? '') === 'move' ? 'selected' : '' }}>{{ __('ui.logs_info_op_move') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'progress']) }}" {{ ($operationTypeFilter ?? '') === 'progress' ? 'selected' : '' }}>{{ __('ui.logs_info_op_progress') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'cancel']) }}" {{ ($operationTypeFilter ?? '') === 'cancel' ? 'selected' : '' }}>{{ __('ui.logs_info_op_cancel') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'health']) }}" {{ ($operationTypeFilter ?? '') === 'health' ? 'selected' : '' }}>{{ __('ui.logs_info_op_health') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'start']) }}" {{ ($operationTypeFilter ?? '') === 'start' ? 'selected' : '' }}>{{ __('ui.logs_info_op_start') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'stop']) }}" {{ ($operationTypeFilter ?? '') === 'stop' ? 'selected' : '' }}>{{ __('ui.logs_info_op_stop') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'status']) }}" {{ ($operationTypeFilter ?? '') === 'status' ? 'selected' : '' }}>{{ __('ui.logs_info_op_status') }}</option>
                    <option value="{{ route('activity-logs.index', ['tab' => 'info', 'operation_type' => 'preview']) }}" {{ ($operationTypeFilter ?? '') === 'preview' ? 'selected' : '' }}>{{ __('ui.logs_info_op_preview') }}</option>
                </select>
            </div>
            <div class="card overflow-hidden">
                <div class="overflow-x-auto scrollbar-slate">
                    <table class="min-w-full text-sm">
                        <thead class="bg-slate-800/60 text-slate-300">
                            <tr>
                                <th class="px-4 py-3 text-left">{{ __('ui.created_at') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_service') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_operation_type') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_method') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_url') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_status') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_request') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_response') }}</th>
                                <th class="px-4 py-3 text-left">{{ __('ui.logs_info_error') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @forelse($infoLogs as $row)
                                <tr class="text-slate-200 align-top" @if($row->error) style="color: rgb(248 113 113);" @endif>
                                    <td class="px-4 py-3 whitespace-nowrap">{{ $row->created_at?->format('Y-m-d H:i:s') }}</td>
                                    <td class="px-4 py-3">{{ $row->service_name }}</td>
                                    <td class="px-4 py-3">{{ $row->operation_type ? (in_array($row->operation_type, ['delete','move','progress','cancel','health','start','stop','status','preview']) ? __('ui.logs_info_op_' . $row->operation_type) : $row->operation_type) : '-' }}</td>
                                    <td class="px-4 py-3">{{ $row->method ?? '-' }}</td>
                                    <td class="px-4 py-3 break-all max-w-xs truncate" title="{{ $row->url }}">{{ $row->url ?? '-' }}</td>
                                    <td class="px-4 py-3">{{ $row->status_code ?? '-' }}</td>
                                    <td class="px-4 py-3 max-w-xs">
                                        @if($row->request)
                                            @php
                                                $reqJson = json_encode($row->request, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
                                                $reqSingle = preg_replace('/\s+/', ' ', $reqJson);
                                            @endphp
                                            <div class="flex items-start gap-1">
                                                <button type="button" class="log-copy-btn shrink-0 p-1 text-slate-400 hover:text-cyan-400 rounded" title="{{ __('ui.logs_copy') }}">
                                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                                </button>
                                                <div class="flex-1 min-w-0">
                                                    <div class="log-collapsible max-w-md min-h-0 scrollbar-slate" data-collapsed="true">
                                                        <span class="log-collapsed-view text-xs bg-slate-800/50 rounded p-2 block truncate">{{ e($reqSingle) }}</span>
                                                        <pre class="log-expanded-view hidden text-xs overflow-x-auto whitespace-pre-wrap break-words bg-slate-800/50 rounded p-2 scrollbar-slate">{{ e($reqJson) }}</pre>
                                                    </div>
                                                    <button type="button" class="log-toggle-btn mt-1 text-xs text-slate-400 hover:text-cyan-400">{{ __('ui.logs_expand') }}</button>
                                                </div>
                                            </div>
                                        @else
                                            -
                                        @endif
                                    </td>
                                    <td class="px-4 py-3 max-w-xs">
                                        @if($row->response)
                                            @php
                                                $resJson = json_encode($row->response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
                                                $resSingle = preg_replace('/\s+/', ' ', $resJson);
                                            @endphp
                                            <div class="flex items-start gap-1">
                                                <button type="button" class="log-copy-btn shrink-0 p-1 text-slate-400 hover:text-cyan-400 rounded" title="{{ __('ui.logs_copy') }}">
                                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                                </button>
                                                <div class="flex-1 min-w-0">
                                                    <div class="log-collapsible max-w-md min-h-0 scrollbar-slate" data-collapsed="true">
                                                        <span class="log-collapsed-view text-xs bg-slate-800/50 rounded p-2 block truncate">{{ e($resSingle) }}</span>
                                                        <pre class="log-expanded-view hidden text-xs overflow-x-auto whitespace-pre-wrap break-words bg-slate-800/50 rounded p-2 scrollbar-slate">{{ e($resJson) }}</pre>
                                                    </div>
                                                    <button type="button" class="log-toggle-btn mt-1 text-xs text-slate-400 hover:text-cyan-400">{{ __('ui.logs_expand') }}</button>
                                                </div>
                                            </div>
                                        @else
                                            -
                                        @endif
                                    </td>
                                    <td class="px-4 py-3 max-w-xs">
                                        @if($row->error)
                                            @php $errSingle = preg_replace('/\s+/', ' ', $row->error); @endphp
                                            <div class="flex items-start gap-1">
                                                <button type="button" class="log-copy-btn shrink-0 p-1 text-slate-400 hover:text-cyan-400 rounded" title="{{ __('ui.logs_copy') }}">
                                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                                </button>
                                                <div class="flex-1 min-w-0">
                                                    <div class="log-collapsible max-w-md min-h-0 scrollbar-slate" data-collapsed="true">
                                                        <span class="log-collapsed-view text-xs bg-slate-800/50 rounded p-2 block truncate">{{ e($errSingle) }}</span>
                                                        <pre class="log-expanded-view hidden text-xs overflow-x-auto whitespace-pre-wrap break-words bg-slate-800/50 rounded p-2 scrollbar-slate">{{ e($row->error) }}</pre>
                                                    </div>
                                                    <button type="button" class="log-toggle-btn mt-1 text-xs text-slate-400 hover:text-cyan-400">{{ __('ui.logs_expand') }}</button>
                                                </div>
                                            </div>
                                        @else
                                            -
                                        @endif
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="9" class="px-4 py-8 text-center text-slate-400">
                                        {{ __('ui.no_info_logs') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="mt-6">
                {{ $infoLogs?->links('pagination::slate') }}
            </div>
        @elseif(($tab ?? 'activity') === 'service')
            <div class="card overflow-hidden">
                @if($serviceLogsError ?? null)
                    <p class="px-4 py-4 text-amber-400">{{ $serviceLogsError }}</p>
                @else
                    <div class="flex justify-end p-2 border-b border-slate-700/50">
                        <button type="button" class="log-copy-btn px-3 py-1 rounded text-xs bg-slate-600 hover:bg-slate-500 text-slate-200" data-copy-target="service-logs-pre" title="{{ __('ui.logs_copy') }}">
                            {{ __('ui.logs_copy') }}
                        </button>
                    </div>
                    <pre id="service-logs-pre" class="p-4 text-xs font-mono text-slate-300 overflow-x-auto overflow-y-auto max-h-[70vh] whitespace-pre-wrap break-words scrollbar-slate">{{ implode("\n", $serviceLogs ?? []) }}</pre>
                @endif
            </div>
        @endif
        </div>
    </div>

    <script>
        (function() {
            var container = document.getElementById('activity-logs-container');
            var contentEl = document.getElementById('activity-logs-content');
            var refreshInterval = 5000;

            function refreshLogs() {
                var logsUrl = window.location.pathname + window.location.search;
                logsUrl += (logsUrl.indexOf('?') >= 0 ? '&' : '?') + '_=' + Date.now();
                var triggerUrl = '{{ route("activity-logs.trigger-preview") }}';
                fetch(triggerUrl, { cache: 'no-store', headers: { 'X-Requested-With': 'XMLHttpRequest' } })
                    .then(function() {
                        return fetch(logsUrl, { cache: 'no-store', headers: { 'X-Requested-With': 'XMLHttpRequest' } });
                    })
                    .then(function(r) { return r.text(); })
                    .then(function(html) {
                        var parser = new DOMParser();
                        var doc = parser.parseFromString(html, 'text/html');
                        var newContent = doc.getElementById('activity-logs-content');
                        if (newContent && contentEl) {
                            contentEl.innerHTML = newContent.innerHTML;
                        }
                    })
                    .catch(function() {});
            }

            setInterval(refreshLogs, refreshInterval);
            document.addEventListener('visibilitychange', function() {
                if (document.visibilityState === 'visible') refreshLogs();
            });

            container.addEventListener('click', function(e) {
                var copyBtn = e.target.closest('.log-copy-btn');
                if (copyBtn) {
                    e.preventDefault();
                    var cell = copyBtn.closest('td');
                    var pre = cell ? cell.querySelector('.log-expanded-view') : null;
                    if (!pre && copyBtn.closest('.service-logs-card')) {
                        pre = copyBtn.closest('.card')?.querySelector('pre');
                    }
                    var text = (pre ? pre.textContent : '').trim();
                    if (!text) return;
                    var orig = copyBtn.innerHTML;
                    var done = function() {
                        copyBtn.innerHTML = '<span class="text-cyan-400 text-xs">✓</span>';
                        setTimeout(function() { copyBtn.innerHTML = orig; }, 1500);
                    };
                    if (navigator.clipboard && navigator.clipboard.writeText) {
                        navigator.clipboard.writeText(text).then(done).catch(function() {
                            var ta = document.createElement('textarea');
                            ta.value = text;
                            ta.style.position = 'fixed';
                            ta.style.left = '-9999px';
                            document.body.appendChild(ta);
                            ta.select();
                            try { if (document.execCommand('copy')) done(); } finally { document.body.removeChild(ta); }
                        });
                    } else {
                        var ta = document.createElement('textarea');
                        ta.value = text;
                        ta.style.position = 'fixed';
                        ta.style.left = '-9999px';
                        document.body.appendChild(ta);
                        ta.select();
                        try { if (document.execCommand('copy')) done(); } finally { document.body.removeChild(ta); }
                    }
                    return;
                }
                var toggleBtn = e.target.closest('.log-toggle-btn');
                if (toggleBtn) {
                    var collapsible = toggleBtn.previousElementSibling;
                    if (!collapsible || !collapsible.classList.contains('log-collapsible')) return;
                    var collapsedView = collapsible.querySelector('.log-collapsed-view');
                    var expandedView = collapsible.querySelector('.log-expanded-view');
                    var isCollapsed = collapsible.getAttribute('data-collapsed') !== 'false';
                    if (isCollapsed) {
                        if (collapsedView) collapsedView.classList.add('hidden');
                        if (expandedView) { expandedView.classList.remove('hidden'); collapsible.style.overflow = 'auto'; }
                        collapsible.setAttribute('data-collapsed', 'false');
                        toggleBtn.textContent = '{{ __("ui.logs_collapse") }}';
                    } else {
                        if (collapsedView) collapsedView.classList.remove('hidden');
                        if (expandedView) expandedView.classList.add('hidden');
                        collapsible.style.overflow = '';
                        collapsible.setAttribute('data-collapsed', 'true');
                        toggleBtn.textContent = '{{ __("ui.logs_expand") }}';
                    }
                }
            });
        })();
    </script>
</x-layouts.app>
