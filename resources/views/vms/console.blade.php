<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div class="mb-4 flex justify-between items-center">
            <div>
                <a href="{{ route('vms.index') }}" class="text-slate-400 hover:text-white text-sm mb-2 inline-block">
                    ← {{ __('ui.virtual_machines') }}
                </a>
                <h1 class="text-xl font-bold text-white">{{ $vm->name }} — {{ __('ui.vm.console') }}</h1>
            </div>
            <a href="{{ route('vms.index') }}" class="px-3 py-1 bg-slate-600/50 text-slate-300 rounded-lg text-sm hover:bg-slate-600">
                {{ __('ui.virtual_machines') }}
            </a>
        </div>

        <div id="vnc-insecure-warning" class="hidden mb-3 p-3 rounded-lg bg-amber-900/50 border border-amber-600 text-amber-200 text-sm">
            {{ __('ui.vm.console_use_https') }} <span id="vnc-https-url" class="font-mono block mt-2"></span>
        </div>
        @if(!empty(env('VNC_SSL_CERT')))
        <div id="vnc-cert-warning" class="hidden mb-3 p-3 rounded-lg bg-blue-900/50 border border-blue-600 text-blue-200 text-sm">
            <div class="flex items-start justify-between gap-2">
                <span>{!! __('ui.vm.console_cert_warning', ['url' => '<a id="vnc-cert-url" href="#" target="_blank" class="underline font-mono"></a>']) !!}</span>
                <button onclick="document.getElementById('vnc-cert-warning').style.display='none'" class="shrink-0 text-blue-300 hover:text-white leading-none text-lg mt-0.5" aria-label="Close">&times;</button>
            </div>
        </div>
        @endif
        <div class="card p-0 overflow-hidden">
            <div class="aspect-video bg-slate-900 min-h-[400px] relative" id="vnc-container">
                <div id="vnc-status" class="absolute inset-0 flex flex-col items-center justify-center text-slate-400 text-center px-4">
                    <span id="vnc-status-text">{{ __('ui.vm.connecting') }}</span>
                    <small id="vnc-status-url" class="text-slate-500 mt-2 text-xs break-all max-w-full"></small>
                    <small class="text-slate-600 mt-2 text-xs">F12 → Console. ?debug=1 в URL для логов.</small>
                    <div id="vnc-debug-hint" class="hidden mt-2 px-2 py-1 bg-slate-700/50 rounded text-amber-400 text-xs">
                        {{ __('ui.vm.console_debug_hint') }}
                    </div>
                </div>
                <div id="vnc-screen" class="absolute inset-0" style="display: none;"></div>
            </div>
            <div class="p-3 border-t border-slate-700 flex gap-2 flex-wrap">
                @if($canStopVm ?? false)
                <button type="button" id="btn-ctrl-alt-del" class="px-3 py-1 bg-slate-600 text-slate-300 rounded text-sm hover:bg-slate-500" title="Ctrl+Alt+Del">
                    Ctrl+Alt+Del
                </button>
                @endif
                <a href="{{ route('vms.index') }}" class="px-3 py-1 bg-slate-600 text-slate-300 rounded text-sm hover:bg-slate-500">
                    {{ __('ui.virtual_machines') }}
                </a>
            </div>
        </div>
    </div>

    <script type="module">
        const wsUrl = @json($wsUrl);
        const debug = new URLSearchParams(window.location.search).get('debug') === '1' || @json(config('app.debug', false));
        const screen = document.getElementById('vnc-screen');
        const status = document.getElementById('vnc-status');
        const btnCtrlAltDel = document.getElementById('btn-ctrl-alt-del');
        const canStopVm = @json($canStopVm ?? false);
        const statusText = document.getElementById('vnc-status-text');
        const statusUrl = document.getElementById('vnc-status-url');
        statusUrl.textContent = wsUrl;

        function showCertWarning() {
            const warn = document.getElementById('vnc-cert-warning');
            const link = document.getElementById('vnc-cert-url');
            if (warn && link && wsUrl.startsWith('wss://')) {
                const u = new URL(wsUrl);
                const certUrl = 'https://' + u.host + '/';
                link.href = certUrl;
                link.textContent = certUrl;
                warn.classList.remove('hidden');
            }
        }

        if (debug) {
            console.log('[VNC] wsUrl:', wsUrl);
            const debugHint = document.getElementById('vnc-debug-hint');
            if (debugHint) debugHint.classList.remove('hidden');
        }

        if (wsUrl.startsWith('wss://')) showCertWarning();

        function showError(msg) {
            status.style.display = 'flex';
            screen.style.display = 'none';
            statusText.textContent = msg;
            statusUrl.textContent = wsUrl;
        }

        const novncUrls = [
            '{{ asset("novnc/core/rfb.js") }}',
            'https://cdn.jsdelivr.net/npm/@novnc/novnc@1.4.0/core/rfb.js',
            'https://unpkg.com/@novnc/novnc@1.4.0/core/rfb.js'
        ];
        let RFB, lastError;
        for (const url of novncUrls) {
            try {
                const m = await import(url);
                RFB = m.default;
                break;
            } catch (e) {
                lastError = e;
            }
        }
        if (RFB) {
            if (!window.isSecureContext && !/^(localhost|127\.0\.0\.1)$/.test(window.location.hostname)) {
                const warn = document.getElementById('vnc-insecure-warning');
                const urlSpan = document.getElementById('vnc-https-url');
                if (warn && urlSpan) {
                    urlSpan.textContent = @json($httpsUrl ?? '');
                    warn.classList.remove('hidden');
                }
            }
            if (debug) console.log('[VNC] Creating RFB, wsUrl:', wsUrl);
            const rfb = new RFB(screen, wsUrl, { shared: true });
            const connectTimeout = setTimeout(function() {
                if (screen.style.display === 'none') {
                    showError('{{ __("ui.vm.connection_timeout") }}');
                }
            }, 15000);
            rfb.addEventListener('connect', function() {
                clearTimeout(connectTimeout);
                status.style.display = 'none';
                screen.style.display = 'block';
            });
                rfb.addEventListener('disconnect', function(e) {
                clearTimeout(connectTimeout);
                const reason = e.detail?.reason || '';
                const clean = e.detail?.clean;
                if (debug) console.log('[VNC] disconnect', { reason, clean, detail: e.detail });
                let msg = clean ? '{{ __("ui.vm.disconnected") }}' : ('{{ __("ui.vm.connection_lost") }}: ' + reason);
                if (reason.includes('1006')) {
                    msg += ' {{ __("ui.vm.connection_lost_1006_hint") }}';
                    if (wsUrl.startsWith('wss://')) showCertWarning();
                }
                showError(msg);
            });
            rfb.addEventListener('securityfailure', function(e) {
                showError('{{ __("ui.vm.security_failure") }}: ' + (e.detail?.reason || 'Unknown'));
            });
            rfb.addEventListener('credentialsrequired', function() {
                showError('{{ __("ui.vm.credentials_required") }}');
            });
            rfb.scaleViewport = true;
            rfb.resizeSession = true;
            if (canStopVm && btnCtrlAltDel) {
                btnCtrlAltDel.addEventListener('click', function() {
                    rfb.sendCtrlAltDel();
                });
            }
        } else {
            showError('noVNC не загружен. ' + (lastError ? lastError.message : ''));
        }
    </script>
</x-layouts.app>
