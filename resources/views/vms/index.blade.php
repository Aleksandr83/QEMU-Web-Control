<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8 flex justify-between items-center">
            <div>
                <h1 class="text-3xl font-bold text-white">{{ __('ui.virtual_machines') }}</h1>
            </div>
            @can('create', App\Models\VirtualMachine::class)
            <a href="{{ route('vms.create') }}" class="btn-primary">
                {{ __('ui.vm.create') }}
            </a>
            @endcan
        </div>

        <div class="card">
            @if($vms->count() > 0)
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="text-left border-b border-slate-700">
                            <tr>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.name') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.preview') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.vnc_port') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.cpu_cores') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.ram_mb') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.vm.disk_size_gb') }}</th>
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
                                                    <div class="text-sm text-slate-400">{{ Str::limit($vm->description, 50) }}</div>
                                                @endif
                                                @if($vm->os_type)
                                                    <div class="text-xs text-slate-500 mt-1">{{ $vm->os_type }}</div>
                                                @endif
                                                @php
                                                    $vmArchitecture = $vm->architecture ?: 'x86_64';
                                                @endphp
                                                <div class="text-xs text-slate-500 mt-1">
                                                    {{ __('ui.vm.architecture') }}: {{ __("ui.vm.architectures.{$vmArchitecture}") }}
                                                </div>
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
                                    <td class="py-4">
                                        <div class="w-44 h-28 rounded-lg border border-slate-700 bg-slate-900/70 overflow-hidden relative">
                                            @if($vm->status === 'running' && $vm->vnc_port)
                                                <a href="{{ route('vms.console', $vm) }}" class="block w-full h-full group cursor-pointer relative" title="{{ __('ui.vm.open_console') }}">
                                                    <div class="vm-preview-placeholder w-full h-full flex items-center justify-center text-xs text-slate-500 px-1" data-default-text="{{ __('ui.vm.no_preview') }}">
                                                        <span class="vm-preview-placeholder-text">{{ __('ui.vm.no_preview') }}</span>
                                                    </div>
                                                    <img
                                                        id="vm-preview-{{ $vm->id }}"
                                                        data-preview-endpoint="{{ route('vms.preview', $vm) }}"
                                                        class="vm-preview-img hidden w-full h-full object-cover group-hover:opacity-90 transition-opacity"
                                                        alt="VM preview {{ $vm->name }}"
                                                    />
                                                    <div class="absolute inset-0 flex items-center justify-center bg-slate-900/60 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
                                                        <span class="text-xs text-white font-medium">{{ __('ui.vm.open_console') }}</span>
                                                    </div>
                                                </a>
                                            @else
                                                <div class="w-full h-full flex items-center justify-center text-xs text-slate-500">
                                                    {{ __('ui.vm.no_preview') }}
                                                </div>
                                            @endif
                                        </div>
                                    </td>
                                    <td class="py-4 text-slate-300">
                                        {{ $vm->vnc_port ?: __('ui.vm.vnc_not_set') }}
                                    </td>
                                    <td class="py-4 text-slate-300">{{ $vm->cpu_cores }}</td>
                                    <td class="py-4 text-slate-300">{{ $vm->ram_mb }}</td>
                                    <td class="py-4 text-slate-300">{{ $vm->disk_size_gb }} GB</td>
                                    <td class="py-4">
                                        @if($vm->status === 'running')
                                            <span class="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-xs font-medium">
                                                {{ __('ui.vm.running') }}
                                            </span>
                                        @elseif($vm->status === 'paused')
                                            <span class="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-xs font-medium">
                                                {{ __('ui.vm.paused') }}
                                            </span>
                                        @elseif($vm->status === 'error')
                                            <span class="px-3 py-1 bg-red-500/20 text-red-400 rounded-full text-xs font-medium">
                                                {{ __('ui.vm.error') }}
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
                                                <button type="button"
                                                    class="vm-action-btn px-3 py-1 bg-red-500/20 text-red-400 rounded-lg text-sm hover:bg-red-500/30 transition-all"
                                                    data-action="stop"
                                                    data-url="{{ route('vms.stop', $vm) }}"
                                                    data-csrf="{{ csrf_token() }}">
                                                    {{ __('ui.vm.stop') }}
                                                </button>
                                                @endcan
                                            @else
                                                @can('start', $vm)
                                                <button type="button"
                                                    class="vm-action-btn px-3 py-1 bg-green-500/20 text-green-400 rounded-lg text-sm hover:bg-green-500/30 transition-all"
                                                    data-action="start"
                                                    data-url="{{ route('vms.start', $vm) }}"
                                                    data-csrf="{{ csrf_token() }}">
                                                    {{ __('ui.vm.start') }}
                                                </button>
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

                <div class="mt-6">
                    {{ $vms->links() }}
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

    <script>
        (function () {
            document.querySelectorAll('.vm-action-btn').forEach(function (btn) {
                btn.addEventListener('click', async function () {
                    const url = btn.dataset.url;
                    const csrf = btn.dataset.csrf;
                    btn.disabled = true;
                    btn.style.opacity = '0.5';
                    try {
                        const res = await fetch(url, {
                            method: 'POST',
                            credentials: 'same-origin',
                            headers: {
                                'X-CSRF-TOKEN': csrf,
                                'X-Requested-With': 'XMLHttpRequest',
                                'Accept': 'application/json',
                            },
                        });
                        if (res.ok) {
                            window.location.reload();
                        } else {
                            btn.disabled = false;
                            btn.style.opacity = '';
                        }
                    } catch (_) {
                        btn.disabled = false;
                        btn.style.opacity = '';
                    }
                });
            });
            const previews = Array.from(document.querySelectorAll('img[data-preview-endpoint]'));
            if (previews.length === 0) return;

            let retryTimeout = null;
            const POLL_INTERVAL = 5000;
            const RETRY_INTERVAL = 2000;

            async function updatePreview(img) {
                const container = img.closest('a');
                const placeholder = container?.querySelector('.vm-preview-placeholder');
                const placeholderText = placeholder?.querySelector('.vm-preview-placeholder-text');
                const noPreviewText = placeholder?.dataset?.defaultText || 'No signal';
                try {
                    const res = await fetch(img.dataset.previewEndpoint, {
                        headers: { 'X-Requested-With': 'XMLHttpRequest' }
                    });
                    const data = res.ok ? await res.json() : null;
                    if (data && data.ok && data.url) {
                        img.onerror = function() {
                            img.classList.add('hidden');
                            if (placeholder) {
                                placeholder.classList.remove('hidden');
                                placeholder.classList.remove('text-red-500');
                                if (placeholderText) placeholderText.textContent = noPreviewText;
                            }
                        };
                        img.src = data.url;
                        img.classList.remove('hidden');
                        if (placeholder) placeholder.classList.add('hidden');
                        return true;
                    }
                    img.classList.add('hidden');
                    if (placeholder) {
                        placeholder.classList.remove('hidden');
                        if (data?.error_message) {
                            placeholder.classList.add('text-red-500');
                            if (placeholderText) placeholderText.textContent = data.error_message;
                        } else {
                            placeholder.classList.remove('text-red-500');
                            if (placeholderText) placeholderText.textContent = noPreviewText;
                        }
                    }
                    return false;
                } catch (_) {
                    img.classList.add('hidden');
                    if (placeholder) {
                        placeholder.classList.remove('hidden');
                        placeholder.classList.remove('text-red-500');
                        if (placeholderText) placeholderText.textContent = noPreviewText;
                    }
                    return false;
                }
            }

            async function refreshAll() {
                const results = await Promise.all(previews.map(updatePreview));
                const anyFailed = results.some(r => !r);
                if (anyFailed && retryTimeout === null) {
                    retryTimeout = setTimeout(() => {
                        retryTimeout = null;
                        refreshAll();
                    }, RETRY_INTERVAL);
                }
            }

            refreshAll();
            setInterval(() => refreshAll(), POLL_INTERVAL);
        })();
    </script>
</x-layouts.app>
