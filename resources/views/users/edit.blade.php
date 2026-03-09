<x-layouts.app>
    <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.user.edit') }}</h1>
        </div>

        <div class="card">
            <form method="POST" action="{{ route('users.update', $user) }}" class="space-y-6">
                @csrf
                @method('PUT')

                <div>
                    <label for="name" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.name') }}</label>
                    <input id="name" name="name" type="text" class="input-field" value="{{ old('name', $user->name) }}" required>
                    @error('name')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                </div>

                <div>
                    <label for="email" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.email') }}</label>
                    <input id="email" name="email" type="email" class="input-field" value="{{ old('email', $user->email) }}" required>
                    @error('email')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                </div>

                <div>
                    <label for="role_id" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.roles') }}</label>
                    <select id="role_id" name="role_id" class="input-field" required>
                        @foreach($roles as $role)
                            <option value="{{ $role->id }}" data-slug="{{ $role->slug }}"
                                {{ (string)old('role_id', optional($user->roles->first())->id) === (string)$role->id ? 'selected' : '' }}>
                                {{ $role->name }}
                            </option>
                        @endforeach
                    </select>
                    @error('role_id')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                </div>

                <div id="vm-permissions-section" class="space-y-3 p-4 rounded-lg bg-slate-800/50 border border-slate-600"
                    style="display: {{ (optional($user->roles->first())->slug ?? 'user') === 'administrator' ? 'none' : 'block' }}">
                    <p class="text-sm font-medium text-slate-300 mb-3">{{ __('ui.user.vm_permissions') }}</p>
                    <div class="grid grid-cols-2 gap-x-8 gap-y-3">
                        @php $p = $user->vmPermissions; @endphp
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_create_vm" value="0">
                            <input type="checkbox" name="can_create_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_create_vm', $p?->can_create_vm ?? true) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_create_vm') }}</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_delete_vm" value="0">
                            <input type="checkbox" name="can_delete_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_delete_vm', $p?->can_delete_vm ?? true) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_delete_vm') }}</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_start_vm" value="0">
                            <input type="checkbox" name="can_start_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_start_vm', $p?->can_start_vm ?? true) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_start_vm') }}</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_stop_vm" value="0">
                            <input type="checkbox" name="can_stop_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_stop_vm', $p?->can_stop_vm ?? true) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_stop_vm') }}</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_edit_others_vm" value="0">
                            <input type="checkbox" name="can_edit_others_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_edit_others_vm', $p?->can_edit_others_vm ?? false) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_edit_others_vm') }}</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="hidden" name="can_delete_others_vm" value="0">
                            <input type="checkbox" name="can_delete_others_vm" value="1" class="rounded border-slate-600"
                                {{ old('can_delete_others_vm', $p?->can_delete_others_vm ?? false) ? 'checked' : '' }}>
                            <span class="text-slate-300">{{ __('ui.user.can_delete_others_vm') }}</span>
                        </label>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label for="password" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.password') }}</label>
                        <input id="password" name="password" type="password" class="input-field" placeholder="{{ __('ui.password_optional') }}">
                        @error('password')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                    </div>
                    <div>
                        <label for="password_confirmation" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.password_confirmation') }}</label>
                        <input id="password_confirmation" name="password_confirmation" type="password" class="input-field">
                    </div>
                </div>

                <div class="flex justify-end gap-4">
                    <a href="{{ route('users.index') }}" class="btn-secondary">{{ __('ui.cancel') }}</a>
                    <button type="submit" class="btn-primary">{{ __('ui.save') }}</button>
                </div>
            </form>
        </div>
    </div>
    <script>
        (function() {
            const roleSelect = document.getElementById('role_id');
            const section = document.getElementById('vm-permissions-section');
            function updateSection() {
                const opt = roleSelect.options[roleSelect.selectedIndex];
                const slug = opt?.dataset?.slug || '';
                const show = slug !== 'administrator';
                section.style.display = show ? 'block' : 'none';
                section.querySelectorAll('input').forEach(inp => { inp.disabled = !show; });
            }
            roleSelect.addEventListener('change', updateSection);
            updateSection();
        })();
    </script>
</x-layouts.app>
