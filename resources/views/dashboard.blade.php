<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.dashboard') }}</h1>
            <p class="text-slate-400 mt-1">{{ __('ui.virtual_machines') }}</p>
        </div>

        @if(auth()->user()->isAdmin())
            <div class="card mb-8" id="host-metrics-card" data-endpoint="{{ route('dashboard.host-metrics') }}">
                <div class="flex justify-between items-center mb-4">
                    <h2 class="text-xl font-bold text-white">{{ __('ui.host_metrics') }}</h2>
                    <span class="text-xs text-slate-400" id="host-metrics-updated">--</span>
                </div>
                @if($serverId = \App\Models\Setting::serverId())
                    <p class="text-sm text-slate-400 mb-4">{{ __('ui.server_id') }}: {{ $serverId }}</p>
                    <table class="text-sm text-slate-400 mb-4">
                        <tr>
                            <td style="padding-right: 0.75rem;">{{ __('ui.external_ip') }}: <span id="network-external-ip">--</span></td>
                            <td><a id="network-http-link" href="#" class="text-cyan-400 hover:text-cyan-300 hover:underline" target="_blank" rel="noopener">HTTP</a>: <span id="network-http-url">--</span></td>
                        </tr>
                        <tr>
                            <td style="padding-right: 0.75rem;">{{ __('ui.internal_ip') }}: <span id="network-internal-ip">--</span></td>
                            <td><a id="network-https-link" href="#" class="text-cyan-400 hover:text-cyan-300 hover:underline" target="_blank" rel="noopener">HTTPS</a>: <span id="network-https-url">--</span></td>
                        </tr>
                    </table>
                @endif
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div>
                        <h3 class="text-sm font-medium text-slate-300 mb-3">{{ __('ui.cpu_per_core') }}</h3>
                        <div id="cpu-cores-grid" class="grid grid-cols-2 md:grid-cols-3 gap-3">
                            <div class="text-slate-500 text-sm">{{ __('ui.loading') }}...</div>
                        </div>
                    </div>
                    <div class="flex justify-end">
                        <div>
                            <h3 class="text-sm font-medium text-slate-300 mb-3">{{ __('ui.memory_usage') }}</h3>
                            <table class="text-sm">
                            <tr>
                                <td class="text-slate-400" style="padding-right:1.25rem; text-align:left;">{{ __('ui.total') }}</td>
                                <td class="text-slate-200" style="text-align:right; min-width:110px;" id="mem-total">--</td>
                            </tr>
                            <tr>
                                <td class="text-slate-400" style="padding-right:1.25rem; text-align:left;">{{ __('ui.used') }}</td>
                                <td class="text-slate-200" style="text-align:right; min-width:110px;" id="mem-used">--</td>
                            </tr>
                            <tr>
                                <td class="text-slate-400" style="padding-right:1.25rem; text-align:left;">{{ __('ui.free') }}</td>
                                <td class="text-slate-200" style="text-align:right; min-width:110px;" id="mem-free">--</td>
                            </tr>
                            <tr>
                                <td class="text-slate-400" style="padding-right:1.25rem; text-align:left;">{{ __('ui.status') }}</td>
                                <td class="text-slate-200" style="text-align:right; min-width:110px;" id="mem-percent">--</td>
                            </tr>
                        </table>
                        </div>
                    </div>
                </div>
            </div>
        @endif

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="card">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-slate-400 text-sm">{{ __('ui.virtual_machines') }}</p>
                        <p class="text-3xl font-bold text-white mt-1">{{ $totalVms }}</p>
                    </div>
                    <div class="w-12 h-12 bg-cyan-500/20 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-cyan-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"/>
                        </svg>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-slate-400 text-sm">{{ __('ui.vm.running') }}</p>
                        <p class="text-3xl font-bold text-green-400 mt-1">{{ $runningVms }}</p>
                    </div>
                    <div class="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="flex items-center justify-between">
                    <div>
                        <p class="text-slate-400 text-sm">{{ __('ui.vm.stopped') }}</p>
                        <p class="text-3xl font-bold text-slate-400 mt-1">{{ $totalVms - $runningVms }}</p>
                    </div>
                    <div class="w-12 h-12 bg-slate-500/20 rounded-xl flex items-center justify-center">
                        <svg class="w-6 h-6 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"/>
                        </svg>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="flex justify-between items-center mb-6">
                <h2 class="text-xl font-bold text-white">{{ __('ui.virtual_machines') }}</h2>
                @can('create', App\Models\VirtualMachine::class)
                <a href="{{ route('vms.create') }}" class="btn-primary">
                    {{ __('ui.create') }}
                </a>
                @endcan
            </div>

            @if($vms->count() > 0)
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="text-left border-b border-slate-700">
                            <tr>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.name') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.cpu_cores') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.ram_mb') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.status') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.actions') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @foreach($vms as $vm)
                                <tr>
                                    <td class="py-4">
                                        <div class="flex items-center space-x-2">
                                            <div>
                                                <div class="font-medium text-white">{{ $vm->name }}</div>
                                                @if($vm->description)
                                                    <div class="text-sm text-slate-400">{{ Str::limit($vm->description, 40) }}</div>
                                                @endif
                                            </div>
                                            @if($vm->autostart)
                                                <span class="inline-flex items-center px-2 py-1 bg-blue-500/20 text-blue-400 rounded text-xs" title="{{ __('ui.vm.autostart') }}">
                                                    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                                                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
                                                    </svg>
                                                </span>
                                            @endif
                                        </div>
                                    </td>
                                    <td class="py-4 text-slate-300">{{ $vm->cpu_cores }}</td>
                                    <td class="py-4 text-slate-300">{{ $vm->ram_mb }} MB</td>
                                    <td class="py-4">
                                        @if($vm->status === 'running')
                                            <span class="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-xs font-medium">
                                                {{ __('ui.vm.running') }}
                                            </span>
                                        @else
                                            <span class="px-3 py-1 bg-slate-500/20 text-slate-400 rounded-full text-xs font-medium">
                                                {{ __('ui.vm.stopped') }}
                                            </span>
                                        @endif
                                    </td>
                                    <td class="py-4">
                                        <div class="flex space-x-2">
                                            @if($vm->isRunning())
                                                @can('stop', $vm)
                                                <form method="POST" action="{{ route('vms.stop', $vm) }}">
                                                    @csrf
                                                    <button type="submit" class="px-3 py-1 bg-red-500/20 text-red-400 rounded-lg text-sm hover:bg-red-500/30 transition-all">
                                                        {{ __('ui.vm.stop') }}
                                                    </button>
                                                </form>
                                                @endcan
                                            @else
                                                @can('start', $vm)
                                                <form method="POST" action="{{ route('vms.start', $vm) }}">
                                                    @csrf
                                                    <button type="submit" class="px-3 py-1 bg-green-500/20 text-green-400 rounded-lg text-sm hover:bg-green-500/30 transition-all">
                                                        {{ __('ui.vm.start') }}
                                                    </button>
                                                </form>
                                                @endcan
                                            @endif
                                            @if(auth()->user()->can('update', $vm) || auth()->user()->can('delete', $vm))
                                            <a href="{{ route('vms.edit', $vm) }}" class="px-3 py-1 bg-blue-500/20 text-blue-400 rounded-lg text-sm hover:bg-blue-500/30 transition-all">
                                                {{ __('ui.edit') }}
                                            </a>
                                            @endif
                                        </div>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @else
                <div class="text-center py-12">
                    <svg class="w-16 h-16 text-slate-600 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"/>
                    </svg>
                    <p class="text-slate-400 mb-4">{{ __('ui.vm.no_vms') }}</p>
                    @can('create', App\Models\VirtualMachine::class)
                    <a href="{{ route('vms.create') }}" class="btn-primary">
                        {{ __('ui.vm.create') }}
                    </a>
                    @endcan
                </div>
            @endif
        </div>
    </div>

    @if(auth()->user()->isAdmin())
        <script>
            (function () {
                const card = document.getElementById('host-metrics-card');
                if (!card) return;

                const endpoint = card.dataset.endpoint;
                const cpuGrid = document.getElementById('cpu-cores-grid');
                const memTotal = document.getElementById('mem-total');
                const memUsed = document.getElementById('mem-used');
                const memFree = document.getElementById('mem-free');
                const memPercent = document.getElementById('mem-percent');
                const updated = document.getElementById('host-metrics-updated');
                const externalIp = document.getElementById('network-external-ip');
                const internalIp = document.getElementById('network-internal-ip');
                const httpLink = document.getElementById('network-http-link');
                const httpsLink = document.getElementById('network-https-link');
                const httpUrl = document.getElementById('network-http-url');
                const httpsUrl = document.getElementById('network-https-url');

                const loadText = @json(__('ui.loading'));
                const updatedText = @json(__('ui.updated'));
                const percentText = @json(__('ui.percent'));

                async function refreshMetrics() {
                    try {
                        const res = await fetch(endpoint, { headers: { 'X-Requested-With': 'XMLHttpRequest' } });
                        if (!res.ok) throw new Error('Request failed');
                        const data = await res.json();

                        const cores = Array.isArray(data.cpu) ? data.cpu : [];
                        if (cores.length === 0) {
                            cpuGrid.innerHTML = `<div class="text-slate-500 text-sm">${loadText}...</div>`;
                        } else {
                            cpuGrid.innerHTML = cores.map(core => `
                                <div class="bg-slate-700/40 rounded-lg px-3 py-2">
                                    <div class="text-slate-400 text-xs mb-1">${core.core}</div>
                                    <div class="text-slate-100 font-semibold">${core.usage_percent}%</div>
                                </div>
                            `).join('');
                        }

                        if (data.memory) {
                            memTotal.textContent = `${data.memory.total_mb} MB`;
                            memUsed.textContent = `${data.memory.used_mb} MB`;
                            memFree.textContent = `${data.memory.free_mb} MB`;
                            memPercent.textContent = `${data.memory.used_percent}% ${percentText}`;
                        }

                        if (data.network) {
                            const ip = data.network.external_ip ?? '';
                            const httpPort = data.network.http_port ?? 0;
                            const httpsPort = data.network.https_port ?? 0;
                            if (externalIp) externalIp.textContent = ip || '--';
                            if (internalIp) internalIp.textContent = data.network.internal_ip ?? '--';
                            const httpFull = (ip && httpPort) ? `http://${ip}:${httpPort}` : '--';
                            const httpsFull = (ip && httpsPort) ? `https://${ip}:${httpsPort}` : '--';
                            if (httpLink) { httpLink.href = (ip && httpPort) ? httpFull : '#'; httpLink.style.pointerEvents = (ip && httpPort) ? 'auto' : 'none'; }
                            if (httpsLink) { httpsLink.href = (ip && httpsPort) ? httpsFull : '#'; httpsLink.style.pointerEvents = (ip && httpsPort) ? 'auto' : 'none'; }
                            if (httpUrl) httpUrl.textContent = httpFull;
                            if (httpsUrl) httpsUrl.textContent = httpsFull;
                        }

                        updated.textContent = `${updatedText}: ${new Date().toLocaleTimeString()}`;
                    } catch (_) {
                        updated.textContent = `${updatedText}: error`;
                    }
                }

                refreshMetrics();
                setInterval(refreshMetrics, 5000);
            })();
        </script>
    @endif
</x-layouts.app>
