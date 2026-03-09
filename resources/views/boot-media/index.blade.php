<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6 flex justify-between items-start">
            <div>
                <h1 class="text-3xl font-bold text-white">{{ __('ui.boot_media.title') }}</h1>
                <p class="text-slate-400 mt-1">{{ __('ui.boot_media.subtitle') }}</p>
            </div>
            <div class="flex items-center gap-2">
                <a href="{{ route('boot-media.index') }}" class="btn-secondary inline-flex items-center gap-2" title="{{ __('ui.boot_media.refresh_list') }}">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                    {{ __('ui.boot_media.refresh_list') }}
                </a>
                <a href="{{ route('activity-logs.index') }}" class="btn-secondary">{{ __('ui.back') }}</a>
            </div>
        </div>

        @if(empty($uploadPaths) && !empty($directories))
            <div class="card mb-6 border-amber-500/30 bg-amber-500/5">
                <p class="text-slate-400 text-sm">{{ __('ui.boot_media.upload_readonly_hint') }}</p>
            </div>
        @elseif(empty($uploadPaths) && empty($directories))
            <div class="card mb-6 border-amber-500/30 bg-amber-500/5">
                <p class="text-slate-400 text-sm">{{ __('ui.boot_media.upload_no_dirs') }}</p>
            </div>
        @endif

        @if(!empty($uploadPaths) && Auth::user()->isAdmin())
            <div class="card mb-6">
                <div class="flex items-center gap-3 mb-4">
                    <div class="w-10 h-10 bg-cyan-500/20 rounded-lg flex items-center justify-center shrink-0">
                        <svg class="w-5 h-5 text-cyan-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>
                    </div>
                    <div>
                        <h2 class="text-lg font-semibold text-white">{{ __('ui.boot_media.upload') }}</h2>
                        <p class="text-slate-500 text-sm">{{ __('ui.boot_media.upload_desc') }}</p>
                    </div>
                </div>
                <div class="mb-3">
                    <label for="upload-target" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.boot_media.upload_path') }}</label>
                    <select id="upload-target" class="input-field">
                        @foreach($uploadPaths as $dir)
                            <option value="{{ e($dir) }}">{{ $dir }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="relative">
                    <input type="file" id="iso-upload" accept=".iso" class="hidden">
                    <label for="iso-upload" class="inline-flex items-center gap-2 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-slate-200 rounded-xl cursor-pointer transition-colors text-sm font-medium">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/></svg>
                        {{ __('ui.boot_media.browse') }}
                    </label>
                </div>
                <div id="upload-progress-wrap" class="mt-4 hidden">
                    <div class="flex items-center justify-between text-sm text-slate-400 mb-2">
                        <span id="upload-filename"></span>
                        <div class="flex items-center gap-2">
                            <span id="upload-percent">0%</span>
                            <button type="button" id="upload-cancel-btn" class="px-2 py-1 text-xs text-slate-400 hover:text-red-400 hover:bg-red-500/10 rounded transition-colors">
                                {{ __('ui.cancel') }}
                            </button>
                        </div>
                    </div>
                    <div class="h-2 bg-slate-700 rounded-full overflow-hidden">
                        <div id="upload-progress-bar" class="h-full bg-gradient-to-r from-cyan-500 to-blue-500 rounded-full transition-all duration-300" style="width: 0%"></div>
                    </div>
                    <div id="upload-stage" class="mt-2 text-xs text-slate-500"></div>
                </div>
            </div>
        @endif

        @if(count($isoList) > 0)
            <div class="card overflow-hidden">
                <div class="overflow-x-auto">
                    <table class="w-full text-sm">
                        <thead>
                            <tr class="border-b border-slate-700">
                                <th class="text-left text-slate-200 font-medium py-3 px-4">{{ __('ui.boot_media.filename') }}</th>
                                <th class="text-left text-slate-200 font-medium py-3 px-4">{{ __('ui.boot_media.directory') }}</th>
                                <th class="text-left text-slate-200 font-medium py-3 px-4">{{ __('ui.boot_media.size') }}</th>
                                <th class="text-left text-slate-200 font-medium py-3 px-4">{{ __('ui.boot_media.path') }}</th>
                                <th class="w-28"></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach($isoList as $iso)
                                <tr class="border-b border-slate-700/50">
                                    <td class="py-3 px-4 text-slate-200 font-mono">{{ $iso['filename'] }}</td>
                                    <td class="py-3 px-4 text-slate-300">{{ $iso['directory'] }}</td>
                                    <td class="py-3 px-4 text-slate-300">{{ $iso['size'] !== null ? number_format($iso['size'] / 1024 / 1024, 1) . ' MB' : '—' }}</td>
                                    <td class="py-3 px-4 text-slate-400 font-mono text-xs break-all">{{ $iso['path'] }}</td>
                                    <td class="py-3 px-4">
                                        <div class="flex items-center gap-2">
                                            <a href="{{ route('boot-media.download', ['f' => strtr(base64_encode($iso['path']), '+/', '-_')]) }}" class="text-slate-400 hover:text-cyan-400 transition-colors" title="{{ __('ui.boot_media.download') }}" download="{{ $iso['filename'] }}">
                                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
                                            </a>
                                            <button type="button" class="copy-path text-slate-400 hover:text-cyan-400 transition-colors" data-path="{{ e($iso['path']) }}" title="{{ __('ui.boot_media.copy_path') }}">
                                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                            </button>
                                            @if(Auth::user()->isAdmin())
                                            <button type="button" class="delete-iso text-slate-400 hover:text-red-400 transition-colors" data-path="{{ e($iso['path']) }}" data-filename="{{ e($iso['filename']) }}" title="{{ __('ui.boot_media.delete') }}">
                                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                                            </button>
                                            @endif
                                        </div>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
        @else
            <div class="card">
                <p class="text-slate-400 mb-2">{{ __('ui.boot_media.no_isos') }}</p>
                <ul class="list-disc list-inside text-slate-400 text-sm space-y-1">
                    @foreach($directories as $dir)
                        <li class="font-mono">{{ $dir }}</li>
                    @endforeach
                </ul>
            </div>
        @endif
    </div>

    <script>
        document.querySelectorAll('.copy-path').forEach(function(btn) {
            btn.addEventListener('click', function() {
                const path = this.dataset.path;
                navigator.clipboard.writeText(path).then(function() {
                    const orig = btn.innerHTML;
                    btn.innerHTML = '<span class="text-cyan-400 text-xs">✓</span>';
                    setTimeout(function() { btn.innerHTML = orig; }, 1500);
                });
            });
        });

        document.querySelectorAll('.delete-iso').forEach(function(btn) {
            btn.addEventListener('click', function() {
                if (!confirm('{{ __("ui.boot_media.delete_confirm") }}'.replace(':name', this.dataset.filename))) return;
                var path = this.dataset.path;
                fetch('{{ route("boot-media.destroy") }}', {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content
                    },
                    body: JSON.stringify({ path: path })
                }).then(function(r) { return r.json().then(function(d) { return { ok: r.ok, data: d }; }); })
                .then(function(res) {
                    if (res.ok) {
                        window.location.reload();
                    } else {
                        alert(res.data.error || '{{ __("ui.boot_media.upload_error") }}');
                    }
                }).catch(function() { alert('{{ __("ui.boot_media.upload_error") }}'); });
            });
        });

        var uploadInput = document.getElementById('iso-upload');
        var uploadXhr = null;
        var progressInterval = null;
        var currentOperationId = null;
        if (uploadInput) {
            var cancelBtn = document.getElementById('upload-cancel-btn');
            if (cancelBtn) {
                cancelBtn.addEventListener('click', function() {
                    if (currentOperationId) {
                        fetch('{{ route("boot-media.cancel") }}', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'Accept': 'application/json',
                                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content
                            },
                            body: JSON.stringify({ operation_id: currentOperationId })
                        });
                        if (progressInterval) clearInterval(progressInterval);
                        progressInterval = null;
                        currentOperationId = null;
                        var wrap = document.getElementById('upload-progress-wrap');
                        var stage = document.getElementById('upload-stage');
                        if (stage) stage.textContent = '{{ __("ui.boot_media.operation_cancelled") }}';
                        setTimeout(function() { wrap.classList.add('hidden'); uploadInput.value = ''; }, 1500);
                    } else if (uploadXhr) {
                        window.__uploadAborted = true;
                        uploadXhr.abort();
                    }
                });
            }
            uploadInput.addEventListener('change', function() {
                var file = this.files[0];
                if (!file) return;
                if (!file.name.toLowerCase().endsWith('.iso')) {
                    alert('{{ __("ui.boot_media.invalid_format") }}');
                    return;
                }
                var wrap = document.getElementById('upload-progress-wrap');
                var bar = document.getElementById('upload-progress-bar');
                var percent = document.getElementById('upload-percent');
                var filename = document.getElementById('upload-filename');
                var stage = document.getElementById('upload-stage');
                wrap.classList.remove('hidden');
                filename.textContent = file.name;
                percent.textContent = '0%';
                bar.style.width = '0%';
                bar.classList.remove('bg-green-500');
                bar.classList.add('bg-gradient-to-r', 'from-cyan-500', 'to-blue-500');
                stage.textContent = '{{ __("ui.boot_media.stage_uploading") }}: {{ e($stagingDir ?? '') }}';
                window.__uploadAborted = false;
                currentOperationId = null;

                var formData = new FormData();
                formData.append('iso', file);
                formData.append('target_dir', document.getElementById('upload-target').value);
                formData.append('_token', document.querySelector('meta[name="csrf-token"]').content);

                uploadXhr = new XMLHttpRequest();
                var xhr = uploadXhr;
                var movePhase = false;
                xhr.upload.addEventListener('progress', function(e) {
                    if (movePhase) return;
                    if (e.lengthComputable) {
                        var uploadPct = (e.loaded / e.total) * 100;
                        var pct = Math.min(50, Math.round(uploadPct * 0.5));
                        percent.textContent = pct + '%';
                        bar.style.width = pct + '%';
                        if (uploadPct >= 99.99 && stage) {
                            movePhase = true;
                            percent.textContent = '50%';
                            bar.style.width = '50%';
                            stage.textContent = '{{ __("ui.boot_media.stage_moving") }}';
                        }
                    }
                });
                xhr.addEventListener('load', function() {
                    uploadXhr = null;
                    if (xhr.status >= 200 && xhr.status < 300) {
                        var r = {};
                        try { r = JSON.parse(xhr.responseText || '{}'); } catch (e) {}
                        if (r.operation_id) {
                            currentOperationId = r.operation_id;
                            percent.textContent = '50%';
                            bar.style.width = '50%';
                            if (stage) stage.textContent = '{{ __("ui.boot_media.stage_moving") }}';
                            progressInterval = setInterval(function() {
                                fetch('{{ route("boot-media.progress", ["operationId" => "__OPID__"]) }}'.replace('__OPID__', encodeURIComponent(r.operation_id)), {
                                    headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' }
                                }).then(function(res) { return res.json(); }).then(function(data) {
                                    var p = data.progress || 0;
                                    var st = data.status || '';
                                    percent.textContent = (50 + Math.round(p * 0.5)) + '%';
                                    bar.style.width = (50 + p * 0.5) + '%';
                                    if (st === 'completed') {
                                        if (progressInterval) clearInterval(progressInterval);
                                        progressInterval = null;
                                        currentOperationId = null;
                                        bar.style.width = '100%';
                                        percent.textContent = '100%';
                                        if (stage) stage.textContent = '{{ __("ui.boot_media.complete") }}';
                                        bar.classList.remove('from-cyan-500', 'to-blue-500');
                                        bar.classList.add('bg-green-500');
                                        setTimeout(function() { window.location.reload(); }, 800);
                                    } else if (st === 'failed' || st === 'cancelled') {
                                        if (progressInterval) clearInterval(progressInterval);
                                        progressInterval = null;
                                        currentOperationId = null;
                                        alert(data.error_message || (st === 'cancelled' ? '{{ __("ui.boot_media.operation_cancelled") }}' : '{{ __("ui.boot_media.upload_error") }}'));
                                        wrap.classList.add('hidden');
                                        uploadInput.value = '';
                                    }
                                }).catch(function() {});
                            }, 500);
                        } else {
                            bar.style.width = '100%';
                            percent.textContent = '100%';
                            if (stage) stage.textContent = '{{ __("ui.boot_media.complete") }}';
                            bar.classList.remove('from-cyan-500', 'to-blue-500');
                            bar.classList.add('bg-green-500');
                            setTimeout(function() { window.location.reload(); }, 800);
                        }
                    } else {
                        var r = {};
                        try { r = JSON.parse(xhr.responseText || '{}'); } catch (e) {}
                        var msg = r.error || r.message || (r.errors && r.errors.iso ? r.errors.iso[0] : null) || '{{ __("ui.boot_media.upload_error") }}';
                        alert(msg);
                        wrap.classList.add('hidden');
                        uploadInput.value = '';
                    }
                    uploadXhr = null;
                });
                xhr.addEventListener('error', function() {
                    if (window.__uploadAborted) { window.__uploadAborted = false; return; }
                    alert('{{ __("ui.boot_media.upload_error") }}');
                    wrap.classList.add('hidden');
                    uploadInput.value = '';
                    uploadXhr = null;
                });
                xhr.addEventListener('abort', function() {
                    wrap.classList.add('hidden');
                    uploadInput.value = '';
                    uploadXhr = null;
                });
                xhr.open('POST', '{{ route("boot-media.store") }}');
                xhr.setRequestHeader('Accept', 'application/json');
                xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
                xhr.send(formData);
            });
        }
    </script>
</x-layouts.app>
