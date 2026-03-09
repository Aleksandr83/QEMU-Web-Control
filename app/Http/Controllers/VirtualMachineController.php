<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Group;
use App\Models\Setting;
use App\Models\User;
use App\Models\VirtualMachine;
use App\Services\QemuService;
use App\Services\VncTokenService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class VirtualMachineController extends Controller
{
    private const OS_TYPE_OPTIONS = [
        'ubuntu',
        'debian',
        'centos',
        'fedora',
        'windows-10',
        'windows-11',
        'other',
    ];

    public function __construct(
        private QemuService $qemuService,
        private VncTokenService $vncTokenService
    ) {
    }

    public function isoFiles(): JsonResponse
    {
        return response()->json($this->scanIsoFiles());
    }

    public function index(): View
    {
        $this->qemuService->syncRunningVmsStatus();
        $user = auth()->user();

        if ($user->isAdmin()) {
            $vms = VirtualMachine::with('user')->latest()->paginate(15);
        } else {
            $vms = VirtualMachine::visibleFor($user)->with('user')->latest()->paginate(15);
        }

        return view('vms.index', compact('vms'));
    }

    public function create(): View
    {
        $this->authorize('create', VirtualMachine::class);

        $vmId = old('vm_id') ?? (string) \Illuminate\Support\Str::uuid();
        $defaultDiskPath = old('primary_disk_path') ?? $this->buildPrimaryDiskPath($vmId);

        return view('vms.create', [
            'vmId' => $vmId,
            'defaultDiskPath' => $defaultDiskPath,
            'osTypeOptions' => self::OS_TYPE_OPTIONS,
            'architectureOptions' => $this->architectureOptions(),
            'isoDirectories' => $this->isoDirectories(),
            'isoFilesByPath' => $this->scanIsoFiles(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('create', VirtualMachine::class);

        $architectureOptions = $this->architectureOptions();
        $validated = $request->validate([
            'vm_id' => 'required|uuid|unique:virtual_machines,vm_id',
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'cpu_cores' => 'required|integer|min:1|max:32',
            'ram_mb' => 'required|integer|min:512|max:65536',
            'primary_disk_size_gb' => 'required|integer|min:1|max:1000',
            'primary_disk_path' => $this->diskPathRules(true),
            'additional_disks' => 'nullable|array',
            'additional_disks.*.size_gb' => 'required|integer|min:1|max:1000',
            'additional_disks.*.path' => $this->diskPathRules(true),
            'os_type' => 'nullable|in:' . implode(',', self::OS_TYPE_OPTIONS),
            'os_type_other' => 'nullable|string|max:255|required_if:os_type,other',
            'architecture' => ['required', Rule::in($architectureOptions)],
            'iso_path_dir' => 'nullable|string',
            'iso_filename' => 'nullable|string',
            'network_type' => 'required|in:user,tap,bridge',
            'vnc_port' => ['nullable', 'integer', 'min:5900', 'max:5999', Rule::unique('virtual_machines', 'vnc_port')],
            'autostart' => 'nullable|boolean',
            'use_audio' => 'nullable|boolean',
            'enable_kvm' => 'nullable|boolean',
        ]);

        $vmId = $validated['vm_id'];
        $primaryDiskPath = $this->resolveDiskPath(
            trim($validated['primary_disk_path']),
            $vmId . '.qcow2'
        );

        $vmPayload = [
            'user_id' => auth()->id(),
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'vm_id' => $vmId,
            'cpu_cores' => $validated['cpu_cores'],
            'ram_mb' => $validated['ram_mb'],
            'disk_size_gb' => $validated['primary_disk_size_gb'],
            'os_type' => $this->resolveOsType($request, $validated['os_type'] ?? null),
            'architecture' => $validated['architecture'],
            'iso_path' => $this->resolveIsoPath($validated['iso_path_dir'] ?? null, $validated['iso_filename'] ?? null),
            'network_type' => $validated['network_type'],
            'vnc_port' => $validated['vnc_port'] ?? null,
            'autostart' => $request->boolean('autostart'),
            'use_audio' => $request->boolean('use_audio'),
            'enable_kvm' => $request->boolean('enable_kvm'),
        ];

        $vm = VirtualMachine::create($vmPayload);
        $additionalDisks = $validated['additional_disks'] ?? [];
        $this->syncVmDisks($vm, (int) $validated['primary_disk_size_gb'], $primaryDiskPath, $additionalDisks);

        ActivityLog::logVm(ActivityLog::ACTION_CREATE, $vm, null, $vm->fresh()->toArray());

        return redirect()->route('vms.index')
            ->with('success', __('ui.messages.created', ['item' => $vm->name]));
    }

    public function edit(VirtualMachine $vm): View
    {
        $this->authorize('view', $vm);

        $canEdit = auth()->user()->can('update', $vm);
        $canDelete = auth()->user()->can('delete', $vm);
        if (!$canEdit && !$canDelete) {
            abort(403, __('ui.vm.edit_unauthorized'));
        }

        $vm->load(['sharedUsers', 'sharedGroups']);
        $disks = $vm->disks()->orderBy('boot_order')->get();
        if ($disks->isEmpty()) {
            $disks = collect([[
                'size_gb' => $vm->disk_size_gb ?: 20,
                'path' => $vm->disk_path ?: '',
            ]]);
        }

        $primaryDisk = $disks->first();
        $additionalDisks = $disks->slice(1)->values();

        $users = null;
        $groups = null;
        if ($canEdit && (auth()->user()->isAdmin() || $vm->user_id === auth()->id())) {
            $users = User::orderBy('name')->get();
            $groups = Group::orderBy('name')->get();
        }

        return view('vms.edit', [
            'vm' => $vm,
            'canEdit' => $canEdit,
            'canDelete' => $canDelete,
            'osTypeOptions' => self::OS_TYPE_OPTIONS,
            'architectureOptions' => $this->architectureOptions(),
            'primaryDisk' => $primaryDisk,
            'additionalDisks' => $additionalDisks,
            'defaultDiskPathHint' => rtrim(config('qemu.vm_storage', '/var/lib/qemu/vms'), '/') . '/',
            'isoDirectories' => $this->isoDirectories(),
            'isoFilesByPath' => $this->scanIsoFiles(),
            'users' => $users,
            'groups' => $groups,
        ]);
    }

    public function update(Request $request, VirtualMachine $vm): RedirectResponse
    {
        $this->authorize('update', $vm);

        $oldValues = $vm->only(['name', 'description', 'cpu_cores', 'ram_mb', 'disk_size_gb', 'architecture']);
        $architectureOptions = $this->architectureOptions();

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'cpu_cores' => 'required|integer|min:1|max:32',
            'ram_mb' => 'required|integer|min:512|max:65536',
            'primary_disk_size_gb' => 'required|integer|min:1|max:1000',
            'primary_disk_path' => $this->diskPathRules(false),
            'additional_disks' => 'nullable|array',
            'additional_disks.*.size_gb' => 'required|integer|min:1|max:1000',
            'additional_disks.*.path' => $this->diskPathRules(true),
            'os_type' => 'nullable|in:' . implode(',', self::OS_TYPE_OPTIONS),
            'os_type_other' => 'nullable|string|max:255|required_if:os_type,other',
            'architecture' => ['required', Rule::in($architectureOptions)],
            'iso_path_dir' => 'nullable|string',
            'iso_filename' => 'nullable|string',
            'network_type' => 'required|in:user,tap,bridge',
            'vnc_port' => [
                'nullable',
                'integer',
                'min:5900',
                'max:5999',
                Rule::unique('virtual_machines', 'vnc_port')->ignore($vm->id),
            ],
            'autostart' => 'nullable|boolean',
            'use_audio' => 'nullable|boolean',
            'enable_kvm' => 'nullable|boolean',
            'shared_with_all' => 'nullable|boolean',
            'shared_user_ids' => 'nullable|array',
            'shared_user_ids.*' => 'exists:users,id',
            'shared_group_ids' => 'nullable|array',
            'shared_group_ids.*' => 'exists:groups,id',
        ]);

        $updatePayload = [
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'cpu_cores' => $validated['cpu_cores'],
            'ram_mb' => $validated['ram_mb'],
            'disk_size_gb' => $validated['primary_disk_size_gb'],
            'os_type' => $this->resolveOsType($request, $validated['os_type'] ?? null),
            'architecture' => $validated['architecture'],
            'iso_path' => $this->resolveIsoPath($validated['iso_path_dir'] ?? null, $validated['iso_filename'] ?? null),
            'network_type' => $validated['network_type'],
            'vnc_port' => $validated['vnc_port'] ?? null,
            'autostart' => $request->boolean('autostart'),
            'use_audio' => $request->boolean('use_audio'),
            'enable_kvm' => $request->boolean('enable_kvm'),
            'shared_with_all' => $request->boolean('shared_with_all'),
        ];
        $vm->update($updatePayload);

        if (auth()->user()->isAdmin() || $vm->user_id === auth()->id()) {
            $vm->sharedUsers()->sync($validated['shared_user_ids'] ?? []);
            $vm->sharedGroups()->sync($validated['shared_group_ids'] ?? []);
        }

        $primaryDiskPath = $this->resolveDiskPath($validated['primary_disk_path'] ?? null, "{$vm->uuid}.qcow2");
        $additionalDisks = $validated['additional_disks'] ?? [];
        $this->syncVmDisks($vm, (int) $validated['primary_disk_size_gb'], $primaryDiskPath, $additionalDisks);

        ActivityLog::logVm(ActivityLog::ACTION_UPDATE, $vm, $oldValues, $vm->fresh()->toArray());

        return redirect()->route('vms.index')
            ->with('success', __('ui.messages.updated', ['item' => $vm->name]));
    }

    public function destroy(VirtualMachine $vm): RedirectResponse
    {
        $this->authorize('delete', $vm);

        if ($vm->isRunning()) {
            $this->qemuService->stop($vm);
        }

        $this->qemuService->deleteDisk($vm);
        
        ActivityLog::logVm(ActivityLog::ACTION_DELETE, $vm, ['name' => $vm->name], null);
        
        $vm->delete();

        return redirect()->route('vms.index')
            ->with('success', __('ui.messages.deleted', ['item' => $vm->name]));
    }

    public function start(VirtualMachine $vm): RedirectResponse|JsonResponse
    {
        $this->authorize('start', $vm);

        if ($this->qemuService->start($vm)) {
            if (request()->ajax()) {
                return response()->json(['success' => true]);
            }
            return back()->with('success', __('ui.messages.started'));
        }

        if (request()->ajax()) {
            return response()->json(['success' => false, 'error' => $this->qemuService->lastError() ?: __('ui.messages.error')]);
        }
        return back()->with('error', $this->qemuService->lastError() ?: __('ui.messages.error'));
    }

    public function stop(VirtualMachine $vm): RedirectResponse|JsonResponse
    {
        $this->authorize('stop', $vm);

        if ($this->qemuService->stop($vm)) {
            if (request()->ajax()) {
                return response()->json(['success' => true]);
            }
            return back()->with('success', __('ui.messages.stopped'));
        }

        if (request()->ajax()) {
            return response()->json(['success' => false, 'error' => __('ui.messages.error')]);
        }
        return back()->with('error', __('ui.messages.error'));
    }

    public function preview(VirtualMachine $vm): JsonResponse
    {
        $this->authorize('view', $vm);
        $result = $this->qemuService->capturePreview($vm);

        return response()->json([
            'ok' => $result['url'] !== null,
            'url' => $result['url'] ? asset($result['url']) . '?v=' . time() : null,
            'error_message' => $result['error_message'],
            'vnc_port' => $vm->vnc_port,
            'running' => $vm->isRunning(),
        ]);
    }

    public function console(Request $request, VirtualMachine $vm): View|RedirectResponse
    {
        $this->authorize('view', $vm);

        if (!$vm->isRunning() || !$vm->vnc_port) {
            return redirect()->route('vms.index')
                ->with('error', __('ui.vm.console_unavailable'));
        }

        $token = $this->vncTokenService->createToken($vm);
        if (!$token) {
            return redirect()->route('vms.index')
                ->with('error', __('ui.vm.console_unavailable'));
        }

        $wsPath = '/vnc/?token=' . urlencode($token);
        $clientHostPort = env('VNC_WS_HOST') ?: config('qemu.vnc_ws_host');
        if (empty($clientHostPort)) {
            $vncPort = config('qemu.vnc_ws_port', 50055);
            $clientHostPort = $request->getHost() . ':' . $vncPort;
        }
        $vncSslCert = env('VNC_SSL_CERT', '');
        $scheme = !empty($vncSslCert) ? 'wss' : 'ws';
        $wsUrl = $scheme . '://' . $clientHostPort . $wsPath;

        Log::info('VNC console opened', [
            'vm_id' => $vm->id,
            'vm_name' => $vm->name,
            'vnc_port' => $vm->vnc_port,
            'client_ip' => $request->ip(),
            'client_host' => $clientHostPort,
            'ws_url' => $wsUrl,
        ]);

        $httpsPort = (int) env('APP_SSL_PORT', 8443);
        $httpsUrl = 'https://' . $request->getHost() . ($httpsPort !== 443 ? ':' . $httpsPort : '') . $request->getRequestUri();

        return view('vms.console', [
            'vm' => $vm,
            'wsUrl' => $wsUrl,
            'canStopVm' => auth()->user()->can('stop', $vm),
            'httpsUrl' => $httpsUrl,
        ]);
    }

    private function resolveOsType(Request $request, ?string $osType): ?string
    {
        if ($osType === 'other') {
            return $request->input('os_type_other');
        }

        return $osType;
    }

    private function architectureOptions(): array
    {
        $options = config('qemu.architectures', ['x86_64']);
        $options = array_values(array_unique(array_filter(array_map('strval', $options))));

        return $options === [] ? ['x86_64'] : $options;
    }

    private function buildPrimaryDiskPath(string $vmId): string
    {
        $prefix = Setting::get('DefaultHddPathPrefix', '/var/qemu/VM/');

        return rtrim($prefix, '/') . '/' . $vmId . '/disk.qcow2';
    }

    private function resolveDiskPath(?string $path, string $defaultFilename): string
    {
        $path = trim((string) $path);
        if ($path === '') {
            return rtrim(config('qemu.vm_storage', '/var/lib/qemu/vms'), '/') . '/' . $defaultFilename;
        }

        if (str_ends_with($path, '.qcow2')) {
            return $path;
        }

        return rtrim($path, '/') . '/' . $defaultFilename;
    }

    private function isoDirectories(): array
    {
        $dirs = config('qemu.iso_directories') ?: ['/var/lib/qemu/iso', '/srv/iso'];
        $fallback = config('qemu.iso_upload_fallback');
        if ($fallback && !in_array($fallback, $dirs, true)) {
            $dirs[] = $fallback;
        }
        return $dirs;
    }

    private function scanIsoFiles(): array
    {
        $result = [];
        foreach ($this->isoDirectories() as $dir) {
            $dir = rtrim($dir, '/');
            if (!is_dir($dir) || !is_readable($dir)) {
                $result[$dir] = [];
                continue;
            }
            $files = [];
            foreach (scandir($dir) ?: [] as $entry) {
                if ($entry !== '.' && $entry !== '..' && str_ends_with(strtolower($entry), '.iso')) {
                    $files[] = $entry;
                }
            }
            sort($files);
            $result[$dir] = $files;
        }
        return $result;
    }

    private function resolveIsoPath(?string $dir, ?string $filename): ?string
    {
        $dir = trim((string) $dir);
        $filename = trim((string) $filename);
        if ($dir === '' || $filename === '') {
            return null;
        }
        $allowedDirs = $this->isoDirectories();
        if (!in_array($dir, $allowedDirs, true)) {
            return null;
        }
        if (str_contains($filename, '/') || str_contains($filename, "\0")) {
            return null;
        }
        return rtrim($dir, '/') . '/' . $filename;
    }

    private function diskPathRules(bool $required): array
    {
        $rules = [$required ? 'required' : 'nullable', 'string', 'max:1000'];
        $rules[] = function (string $attribute, mixed $value, \Closure $fail): void {
            $path = trim((string) $value);
            if ($path === '') {
                return;
            }

            if (str_contains($path, "\0")) {
                $fail("The {$attribute} contains invalid characters.");
                return;
            }

            if (str_contains($path, '..')) {
                $fail("The {$attribute} must not contain parent directory traversal.");
                return;
            }

            if (!str_starts_with($path, '/')) {
                $fail("The {$attribute} must be an absolute Linux path.");
            }
        };

        return $rules;
    }

    private function syncVmDisks(VirtualMachine $vm, int $primarySizeGb, string $primaryPath, array $additionalDisks): void
    {
        $rows = [[
            'size_gb' => $primarySizeGb,
            'path' => $primaryPath,
        ]];

        foreach ($additionalDisks as $index => $disk) {
            $rows[] = [
                'size_gb' => (int) $disk['size_gb'],
                'path' => $this->resolveDiskPath(
                    $disk['path'] ?? null,
                    sprintf('%s-disk-%d.qcow2', $vm->uuid, $index + 2)
                ),
            ];
        }

        $vm->disks()->delete();
        foreach ($rows as $idx => $row) {
            $vm->disks()->create([
                'path' => $row['path'],
                'size_gb' => $row['size_gb'],
                'interface' => 'virtio',
                'boot_order' => $idx + 1,
            ]);
        }

        $vm->update([
            'disk_path' => $primaryPath,
            'disk_size_gb' => $primarySizeGb,
        ]);
    }
}
