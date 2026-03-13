<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.vm.create') }}</h1>
        </div>

        <div class="card">
            <form id="vm-create-form" method="POST" action="{{ route('vms.store') }}" class="space-y-6">
                @csrf
                <input type="hidden" name="vm_id" value="{{ $vmId ?? '' }}">

                <div>
                    <label for="name" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.vm.name') }}
                    </label>
                    <input id="name" type="text" name="name" value="{{ old('name') }}" required
                           class="input-field">
                    @error('name')
                        <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="description" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.description') }}
                    </label>
                    <textarea id="description" name="description" rows="3"
                              class="input-field">{{ old('description') }}</textarea>
                </div>

                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label for="cpu_cores" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.cpu_cores') }}
                        </label>
                        <input id="cpu_cores" type="number" name="cpu_cores" value="{{ old('cpu_cores', 2) }}" required min="1" max="32"
                               class="input-field">
                        @error('cpu_cores')
                            <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                        @enderror
                    </div>

                    <div>
                        <label for="ram_mb" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.ram_mb') }}
                        </label>
                        <input id="ram_mb" type="number" name="ram_mb" value="{{ old('ram_mb', 2048) }}" required min="512" step="512"
                               class="input-field">
                        @error('ram_mb')
                            <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                        @enderror
                    </div>
                </div>

                <div class="space-y-4">
                    <h2 class="text-sm font-semibold text-slate-200">{{ __('ui.vm.primary_disk') }}</h2>
                    @php
                        $primaryDiskPathFull = old('primary_disk_path', $defaultDiskPath ?? '');
                        $primaryDiskPathDir = $primaryDiskPathFull ? rtrim(dirname($primaryDiskPathFull), '/') . '/' : '';
                        $primaryDiskFilename = $primaryDiskPathFull ? basename($primaryDiskPathFull) : '';
                    @endphp
                    <div class="overflow-x-auto scrollbar-slate space-y-4">
                        <div class="grid disk-grid" style="grid-template-columns: 8rem 80px 600px 200px auto; gap: 10px; align-items: end;">
                            <div class="flex flex-col">
                                <label for="primary_disk_size_gb" class="block text-sm font-medium text-slate-300 mb-1 whitespace-nowrap">
                                    {{ __('ui.vm.disk_size_gb') }}
                                </label>
                                <input id="primary_disk_size_gb" type="number" name="primary_disk_size_gb" value="{{ old('primary_disk_size_gb', 20) }}" required min="1"
                                       class="input-field w-20">
                            </div>
                            <div></div>
                            <div class="flex flex-col min-w-0">
                                <label for="primary_disk_path_dir" class="block text-sm font-medium text-slate-300 mb-1">
                                    {{ __('ui.vm.disk_path_dir') }}
                                    <span id="disk_path_tooltip" class="ml-0.5 text-slate-500 cursor-help align-middle" title="{{ $primaryDiskPathFull }}">
                                        <svg class="w-4 h-4 inline" fill="currentColor" viewBox="0 0 20 20">
                                            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
                                        </svg>
                                    </span>
                                </label>
                                <div class="flex items-center gap-2">
                                    <div style="width: 550px; flex-shrink: 0;">
                                    <input id="primary_disk_path_dir" type="text" value="{{ $primaryDiskPathDir }}"
                                           readonly
                                           class="input-field disk-path-input bg-slate-800/50 cursor-not-allowed font-mono text-sm">
                                    </div>
                                    <button type="button" id="disk_path_copy_btn" class="disk-path-copy-btn shrink-0 p-2 text-slate-400 hover:text-cyan-400 transition-colors rounded"
                                            title="{{ __('ui.vm.disk_path_copy') }}" data-copy-target="primary_disk_path_dir">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                    </button>
                                </div>
                            </div>
                            <div class="flex flex-col min-w-0">
                                <label for="primary_disk_filename" class="block text-sm font-medium text-slate-300 mb-1">
                                    {{ __('ui.vm.disk_filename') }}
                                </label>
                                <input id="primary_disk_filename" type="text" value="{{ $primaryDiskFilename }}"
                                       readonly
                                       class="input-field bg-slate-800/50 cursor-not-allowed font-mono text-sm w-[200px]">
                            </div>
                            <div class="flex flex-col">
                                <label class="block text-sm font-medium text-slate-300 mb-1 invisible">{{ __('ui.vm.disk_path_manual') }}</label>
                                <button type="button" id="disk_path_manual_btn" class="btn-secondary text-sm px-4 flex items-center justify-center"
                                        style="height: 3rem; min-height: 3rem;"
                                        data-default="{{ $defaultDiskPath ?? '' }}">
                                    {{ __('ui.vm.disk_path_manual') }}
                                </button>
                            </div>
                        </div>
                        @error('primary_disk_size_gb')
                            <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                        @enderror
                        @error('primary_disk_path')
                            <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                        @enderror
                        <input type="hidden" id="primary_disk_path" name="primary_disk_path" value="{{ $primaryDiskPathFull }}">
                        <div>
                            <button type="button" id="add-disk-btn" class="btn-primary text-xs py-1.5">
                                {{ __('ui.vm.add_disk') }}
                            </button>
                        </div>
                        @php
                            $additionalDisksOld = old('additional_disks', []);
                        @endphp
                        <div id="additional-disks-container" class="space-y-4">
                            @foreach($additionalDisksOld as $idx => $disk)
                                @php
                                    $addPath = $disk['path'] ?? '';
                                    $addPathDir = $addPath ? rtrim(dirname($addPath), '/') . '/' : '';
                                    $addFilename = $addPath ? basename($addPath) : '';
                                @endphp
                                <div class="space-y-1 additional-disk-row">
                                <div class="grid disk-grid" style="grid-template-columns: 8rem 80px 600px 200px auto; gap: 10px; align-items: end;">
                                    <div class="flex flex-col">
                                        <label class="block text-sm font-medium text-slate-300 mb-1 whitespace-nowrap">{{ __('ui.vm.disk_size_gb') }}</label>
                                        <input type="number" min="1" name="additional_disks[{{ $idx }}][size_gb]"
                                               value="{{ $disk['size_gb'] ?? '' }}"
                                               class="input-field w-20">
                                        <input type="hidden" name="additional_disks[{{ $idx }}][path]" class="additional-disk-path-hidden" value="{{ $addPath }}">
                                    </div>
                                    <div></div>
                                    <div class="flex flex-col min-w-0">
                                        <label class="block text-sm font-medium text-slate-300 mb-1">{{ __('ui.vm.disk_path_dir') }}</label>
                                        <div class="flex items-center gap-2">
                                            <div style="width: 550px; flex-shrink: 0;">
                                                <input type="text" class="additional-disk-path-dir input-field disk-path-input font-mono text-sm"
                                                       value="{{ $addPathDir }}">
                                            </div>
                                            <button type="button" class="additional-disk-copy-btn shrink-0 p-2 text-slate-400 hover:text-cyan-400 transition-colors rounded"
                                                    title="{{ __('ui.vm.disk_path_copy') }}">
                                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                                            </button>
                                        </div>
                                    </div>
                                    <div class="flex flex-col min-w-0">
                                        <label class="block text-sm font-medium text-slate-300 mb-1">{{ __('ui.vm.disk_filename') }}</label>
                                        <input type="text" class="additional-disk-filename input-field font-mono text-sm w-[200px]"
                                               value="{{ $addFilename }}">
                                    </div>
                                    <div class="flex flex-col">
                                        <label class="block text-sm font-medium text-slate-300 mb-1 invisible">{{ __('ui.vm.remove_disk') }}</label>
                                        <button type="button" class="btn-danger text-sm px-4 flex items-center justify-center remove-disk-btn"
                                                style="height: 3rem; min-height: 3rem;">
                                            {{ __('ui.vm.remove_disk') }}
                                        </button>
                                    </div>
                                </div>
                                @error("additional_disks.$idx.size_gb")
                                    <p class="text-sm text-red-400">{{ $message }}</p>
                                @enderror
                                </div>
                            @endforeach
                        </div>
                    </div>
                </div>

                <div>
                    <label for="os_type" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.vm.os_type') }}
                    </label>
                    @php
                        $selectedOsType = old('os_type');
                        $knownOsTypes = $osTypeOptions ?? [];
                        $isCustomOsType = $selectedOsType && !in_array($selectedOsType, $knownOsTypes, true);
                    @endphp
                    <select id="os_type" name="os_type" class="input-field">
                        <option value="">{{ __('ui.vm.os_types.none') }}</option>
                        @foreach(($osTypeOptions ?? []) as $osTypeOption)
                            <option value="{{ $osTypeOption }}"
                                {{ ($isCustomOsType ? 'other' : $selectedOsType) === $osTypeOption ? 'selected' : '' }}>
                                {{ __("ui.vm.os_types.$osTypeOption") }}
                            </option>
                        @endforeach
                    </select>
                    <div id="os_type_other_wrap" class="mt-3 {{ (($isCustomOsType ? 'other' : $selectedOsType) === 'other') ? '' : 'hidden' }}">
                        <label for="os_type_other" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.os_type_other') }}
                        </label>
                        <input id="os_type_other" type="text" name="os_type_other"
                               value="{{ old('os_type_other', $isCustomOsType ? $selectedOsType : '') }}"
                               placeholder="{{ __('ui.vm.os_type_other_placeholder') }}"
                               class="input-field">
                    </div>
                    @error('os_type')
                        <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                    @enderror
                    @error('os_type_other')
                        <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="architecture" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.vm.architecture') }}
                    </label>
                    @php
                        $archOptions = $architectureOptions ?? ['x86_64'];
                        $selectedArchitecture = old('architecture', $archOptions[0] ?? 'x86_64');
                    @endphp
                    <select id="architecture" name="architecture" required class="input-field">
                        @foreach($archOptions as $architectureOption)
                            <option value="{{ $architectureOption }}" {{ $selectedArchitecture === $architectureOption ? 'selected' : '' }}>
                                {{ __("ui.vm.architectures.$architectureOption") }}
                            </option>
                        @endforeach
                    </select>
                    @error('architecture')
                        <p class="mt-1 text-sm text-red-400">{{ $message }}</p>
                    @enderror
                </div>

                <div class="grid grid-cols-2 gap-4" id="iso_select_wrap" data-iso-files="{{ json_encode($isoFilesByPath ?? []) }}" data-selected-filename="{{ old('iso_filename') }}">
                    <div>
                        <label for="iso_path_dir" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.iso_path_dir') }}
                        </label>
                        <div class="flex gap-2 items-center">
                            <select id="iso_path_dir" name="iso_path_dir" class="input-field flex-1 min-w-0">
                            <option value="">{{ __('ui.vm.iso_none') }}</option>
                            @foreach($isoDirectories ?? [] as $dir)
                                <option value="{{ $dir }}" {{ old('iso_path_dir') === $dir ? 'selected' : '' }}>{{ $dir }}</option>
                            @endforeach
                        </select>
                            <button type="button" id="iso_path_dir_copy_btn" class="iso-path-dir-copy-btn shrink-0 p-2 text-slate-400 hover:text-cyan-400 transition-colors rounded"
                                    title="{{ __('ui.vm.disk_path_copy') }}">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                            </button>
                        </div>
                    </div>
                    <div>
                        <label for="iso_filename" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.iso_filename') }}
                        </label>
                        <select id="iso_filename" name="iso_filename" class="input-field">
                            <option value="">{{ __('ui.vm.iso_none') }}</option>
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label for="network_type" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.network_type') }}
                        </label>
                        <select id="network_type" name="network_type" required class="input-field">
                            <option value="user" {{ old('network_type', 'user') === 'user' ? 'selected' : '' }}>User (NAT)</option>
                            <option value="tap" {{ old('network_type') === 'tap' ? 'selected' : '' }}>TAP</option>
                            <option value="bridge" {{ old('network_type') === 'bridge' ? 'selected' : '' }}>Bridge</option>
                        </select>
                    </div>

                    <div>
                        <label for="vnc_port" class="block text-sm font-medium text-slate-300 mb-2">
                            {{ __('ui.vm.vnc_port') }}
                        </label>
                        <input id="vnc_port" type="number" name="vnc_port" value="{{ old('vnc_port') }}" placeholder="5900" min="5900" max="5999"
                               class="input-field">
                        <p class="mt-1 text-xs text-slate-500">{{ __('ui.vm.vnc_port_hint') }}</p>
                    </div>
                </div>

                <div id="network_interface_wrapper" class="{{ old('network_type', 'user') === 'bridge' ? '' : 'hidden' }}">
                    <label for="network_interface" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.vm.network_interface') }}
                    </label>
                    <select id="network_interface" name="network_interface" class="input-field">
                        <option value="">{{ __('ui.vm.network_interface_default') }}</option>
                        @foreach($networkInterfaces ?? [] as $iface)
                            <option value="{{ $iface['name'] ?? '' }}" {{ old('network_interface') === ($iface['name'] ?? '') ? 'selected' : '' }}>
                                {{ ($iface['name'] ?? '') }}{{ !empty($iface['bridge']) ? ' (' . ($iface['bridge']) . ')' : '' }}
                            </option>
                        @endforeach
                    </select>
                    <p class="mt-1 text-xs text-slate-500">{{ __('ui.vm.network_interface_hint') }}</p>
                </div>

                <div class="flex items-center">
                    <input id="autostart" type="checkbox" name="autostart" value="1" {{ old('autostart') ? 'checked' : '' }}
                           class="rounded bg-slate-700 border-slate-600 text-cyan-500 focus:ring-cyan-500 w-4 h-4">
                    <label for="autostart" class="ml-2 text-sm text-slate-300">
                        {{ __('ui.vm.autostart') }}
                    </label>
                    <span class="ml-2 text-xs text-slate-500">{{ __('ui.vm.autostart_desc') }}</span>
                </div>

                <div class="flex items-center">
                    <input id="use_audio" type="checkbox" name="use_audio" value="1" {{ old('use_audio') ? 'checked' : '' }}
                           class="rounded bg-slate-700 border-slate-600 text-cyan-500 focus:ring-cyan-500 w-4 h-4">
                    <label for="use_audio" class="ml-2 text-sm text-slate-300">
                        {{ __('ui.vm.use_audio') }}
                    </label>
                    <span class="ml-2 text-xs text-slate-500">{{ __('ui.vm.use_audio_desc') }}</span>
                </div>

                <div class="flex items-center">
                    <input id="enable_kvm" type="checkbox" name="enable_kvm" value="1" {{ old('enable_kvm', true) ? 'checked' : '' }}
                           class="rounded bg-slate-700 border-slate-600 text-cyan-500 focus:ring-cyan-500 w-4 h-4">
                    <label for="enable_kvm" class="ml-2 text-sm text-slate-300">
                        {{ __('ui.vm.enable_kvm') }}
                    </label>
                    <span class="ml-2 text-xs text-slate-500">{{ __('ui.vm.enable_kvm_desc') }}</span>
                </div>

                <div class="flex justify-end space-x-4 pt-4">
                    <a href="{{ route('vms.index') }}" class="btn-secondary">
                        {{ __('ui.cancel') }}
                    </a>
                    <button type="submit" class="btn-primary">
                        {{ __('ui.create') }}
                    </button>
                </div>
            </form>
        </div>
    </div>

    <script>
        (function () {
            const diskPathHidden = document.getElementById('primary_disk_path');
            const diskPathDir = document.getElementById('primary_disk_path_dir');
            const diskFilename = document.getElementById('primary_disk_filename');
            const diskPathManualBtn = document.getElementById('disk_path_manual_btn');
            const diskPathCopyBtn = document.getElementById('disk_path_copy_btn');
            const diskPathTooltip = document.getElementById('disk_path_tooltip');

            function syncPrimaryDiskPath() {
                const dir = (diskPathDir?.value || '').trim();
                const fn = (diskFilename?.value || '').trim();
                const full = dir ? (dir.endsWith('/') ? dir : dir + '/') + fn : fn;
                if (diskPathHidden) diskPathHidden.value = full;
                if (diskPathTooltip) diskPathTooltip.setAttribute('title', full);
            }

            if (diskPathDir && diskFilename && diskPathManualBtn) {
                const manualText = '{{ __('ui.vm.disk_path_manual') }}';
                const revertText = '{{ __('ui.vm.disk_path_revert') }}';
                const defaultDir = @json($primaryDiskPathDir);
                const defaultFn = @json($primaryDiskFilename);

                diskPathDir.addEventListener('input', syncPrimaryDiskPath);
                diskFilename.addEventListener('input', syncPrimaryDiskPath);
                diskPathHidden?.form?.addEventListener('submit', syncPrimaryDiskPath);

                diskPathManualBtn.addEventListener('click', function () {
                    const isReadonly = diskPathDir.readOnly;
                    if (isReadonly) {
                        diskPathDir.readOnly = false;
                        diskFilename.readOnly = false;
                        diskPathDir.classList.remove('bg-slate-800/50', 'cursor-not-allowed');
                        diskFilename.classList.remove('bg-slate-800/50', 'cursor-not-allowed');
                        diskPathManualBtn.textContent = revertText;
                    } else {
                        diskPathDir.readOnly = true;
                        diskFilename.readOnly = true;
                        diskPathDir.value = defaultDir;
                        diskFilename.value = defaultFn;
                        diskPathDir.classList.add('bg-slate-800/50', 'cursor-not-allowed');
                        diskFilename.classList.add('bg-slate-800/50', 'cursor-not-allowed');
                        diskPathManualBtn.textContent = manualText;
                        syncPrimaryDiskPath();
                    }
                });
            }

            function copyToClipboard(text, btn) {
                if (!text) return;
                function showDone() {
                    const orig = btn.innerHTML;
                    btn.innerHTML = '<span class="text-cyan-400 text-xs">✓</span>';
                    setTimeout(function () { btn.innerHTML = orig; }, 1500);
                }
                if (navigator.clipboard?.writeText) {
                    navigator.clipboard.writeText(text).then(showDone).catch(function () {
                        fallbackCopy(text);
                        showDone();
                    });
                } else {
                    fallbackCopy(text);
                    showDone();
                }
            }
            function fallbackCopy(text) {
                const ta = document.createElement('textarea');
                ta.value = text;
                ta.style.position = 'fixed';
                ta.style.left = '-9999px';
                document.body.appendChild(ta);
                ta.select();
                try { document.execCommand('copy'); } catch (e) {}
                document.body.removeChild(ta);
            }

            if (diskPathCopyBtn) {
                diskPathCopyBtn.addEventListener('click', function () {
                    const text = (diskPathDir?.value || '').trim();
                    copyToClipboard(text, diskPathCopyBtn);
                });
            }

            const isoPathDirCopyBtn = document.getElementById('iso_path_dir_copy_btn');
            if (isoPathDirCopyBtn) {
                isoPathDirCopyBtn.addEventListener('click', function () {
                    const sel = document.getElementById('iso_path_dir');
                    const text = (sel?.value || '').trim();
                    copyToClipboard(text, isoPathDirCopyBtn);
                });
            }

            const networkTypeEl = document.getElementById('network_type');
            const networkInterfaceWrapper = document.getElementById('network_interface_wrapper');
            if (networkTypeEl && networkInterfaceWrapper) {
                function toggleNetworkInterface() {
                    networkInterfaceWrapper.classList.toggle('hidden', networkTypeEl.value !== 'bridge');
                }
                networkTypeEl.addEventListener('change', toggleNetworkInterface);
            }

            document.addEventListener('click', function (e) {
                const copyBtn = e.target.closest('.additional-disk-copy-btn');
                if (copyBtn) {
                    e.preventDefault();
                    const pathDir = copyBtn.closest('.additional-disk-row')?.querySelector('.additional-disk-path-dir');
                    const text = (pathDir?.value || '').trim();
                    copyToClipboard(text, copyBtn);
                }
            });

            const osType = document.getElementById('os_type');
            const osTypeOtherWrap = document.getElementById('os_type_other_wrap');
            const disksContainer = document.getElementById('additional-disks-container');
            const addDiskBtn = document.getElementById('add-disk-btn');
            let diskIndex = {{ count(old('additional_disks', [])) }};

            if (!osType || !osTypeOtherWrap) return;

            function toggleOsTypeOther() {
                const show = osType.value === 'other';
                osTypeOtherWrap.classList.toggle('hidden', !show);
            }

            function syncAdditionalDiskPath(row) {
                const pathDir = row.querySelector('.additional-disk-path-dir');
                const filename = row.querySelector('.additional-disk-filename');
                const hidden = row.querySelector('.additional-disk-path-hidden');
                if (!pathDir || !filename || !hidden) return;
                const dir = (pathDir.value || '').trim();
                const name = (filename.value || '').trim();
                hidden.value = dir && name ? (dir.endsWith('/') ? dir : dir + '/') + name : dir || name || '';
            }

            function createDiskRow() {
                const wrapper = document.createElement('div');
                wrapper.className = 'space-y-1 additional-disk-row';
                const row = document.createElement('div');
                row.className = 'grid disk-grid';
                row.style.gridTemplateColumns = '8rem 80px 600px 200px auto';
                row.style.gap = '10px';
                row.style.alignItems = 'end';
                row.innerHTML = `
                    <div class="flex flex-col">
                        <label class="block text-sm font-medium text-slate-300 mb-1 whitespace-nowrap">{{ __('ui.vm.disk_size_gb') }}</label>
                        <input type="number" min="1" name="additional_disks[${diskIndex}][size_gb]"
                               class="input-field w-20">
                        <input type="hidden" name="additional_disks[${diskIndex}][path]" class="additional-disk-path-hidden" value="">
                    </div>
                    <div></div>
                    <div class="flex flex-col min-w-0">
                        <label class="block text-sm font-medium text-slate-300 mb-1">{{ __('ui.vm.disk_path_dir') }}</label>
                        <div class="flex items-center gap-2">
                            <div style="width: 550px; flex-shrink: 0;">
                                <input type="text" class="additional-disk-path-dir input-field disk-path-input font-mono text-sm">
                            </div>
                            <button type="button" class="additional-disk-copy-btn shrink-0 p-2 text-slate-400 hover:text-cyan-400 transition-colors rounded"
                                    title="{{ __('ui.vm.disk_path_copy') }}">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                            </button>
                        </div>
                    </div>
                    <div class="flex flex-col min-w-0">
                        <label class="block text-sm font-medium text-slate-300 mb-1">{{ __('ui.vm.disk_filename') }}</label>
                        <input type="text" class="additional-disk-filename input-field font-mono text-sm w-[200px]">
                    </div>
                    <div class="flex flex-col">
                        <label class="block text-sm font-medium text-slate-300 mb-1 invisible">{{ __('ui.vm.remove_disk') }}</label>
                        <button type="button" class="btn-danger text-sm px-4 flex items-center justify-center remove-disk-btn"
                                style="height: 3rem; min-height: 3rem;">
                            {{ __('ui.vm.remove_disk') }}
                        </button>
                    </div>
                `;
                wrapper.appendChild(row);
                wrapper.querySelectorAll('.additional-disk-path-dir, .additional-disk-filename').forEach(function (el) {
                    el.addEventListener('input', function () { syncAdditionalDiskPath(wrapper); });
                    el.addEventListener('change', function () { syncAdditionalDiskPath(wrapper); });
                });
                diskIndex += 1;
                return wrapper;
            }

            function bindRemoveHandlers() {
                disksContainer.querySelectorAll('.remove-disk-btn').forEach((btn) => {
                    btn.onclick = () => {
                        btn.closest('.additional-disk-row')?.remove();
                    };
                });
            }

            osType.addEventListener('change', toggleOsTypeOther);
            toggleOsTypeOther();

            const isoPathDir = document.getElementById('iso_path_dir');
            const isoFilename = document.getElementById('iso_filename');
            const isoWrap = document.getElementById('iso_select_wrap');
            if (isoPathDir && isoFilename && isoWrap) {
                let isoFiles = JSON.parse(isoWrap.dataset.isoFiles || '{}');
                const noneLabel = '{{ __('ui.vm.iso_none') }}';
                const isoFilesUrl = '{{ route("vms.iso-files") }}';
                function updateIsoFilename() {
                    const dir = isoPathDir.value;
                    const selected = isoFilename.value || isoWrap.dataset.selectedFilename || '';
                    isoFilename.innerHTML = '<option value="">' + noneLabel + '</option>';
                    if (dir && isoFiles[dir]) {
                        isoFiles[dir].forEach(function (f) {
                            const opt = document.createElement('option');
                            opt.value = f;
                            opt.textContent = f;
                            if (f === selected) opt.selected = true;
                            isoFilename.appendChild(opt);
                        });
                    }
                }
                function refreshIsoFiles(cb) {
                    fetch(isoFilesUrl, { headers: { 'X-Requested-With': 'XMLHttpRequest' } })
                        .then(function (r) { return r.json(); })
                        .then(function (data) {
                            isoFiles = data;
                            updateIsoFilename();
                            if (cb) cb();
                        })
                        .catch(function () { if (cb) cb(); });
                }
                isoPathDir.addEventListener('change', function () { refreshIsoFiles(); });
                isoFilename.addEventListener('focus', function () { refreshIsoFiles(); });
                updateIsoFilename();
            }

            if (addDiskBtn && disksContainer) {
                addDiskBtn.addEventListener('click', () => {
                    disksContainer.appendChild(createDiskRow());
                    bindRemoveHandlers();
                });
                bindRemoveHandlers();
                disksContainer.querySelectorAll('.additional-disk-row').forEach(function (wrapper) {
                    wrapper.querySelectorAll('.additional-disk-path-dir, .additional-disk-filename').forEach(function (el) {
                        el.addEventListener('input', function () { syncAdditionalDiskPath(wrapper); });
                        el.addEventListener('change', function () { syncAdditionalDiskPath(wrapper); });
                    });
                });
            }

            const vmForm = document.getElementById('vm-create-form');
            if (vmForm && disksContainer) {
                vmForm.addEventListener('submit', function () {
                    disksContainer.querySelectorAll('.additional-disk-row').forEach(syncAdditionalDiskPath);
                });
            }
        })();
    </script>
</x-layouts.app>
