<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8 flex justify-between items-center">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.users') }}</h1>
            <a href="{{ route('users.create') }}" class="btn-primary">
                {{ __('ui.user.create') }}
            </a>
        </div>

        <div class="card">
            <form method="GET" action="{{ route('users.index') }}" class="mb-6 grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="md:col-span-2">
                    <label for="q" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.search') }}</label>
                    <input id="q" name="q" type="text" class="input-field"
                           placeholder="{{ __('ui.search_users_placeholder') }}"
                           value="{{ $search ?? '' }}">
                </div>
                <div>
                    <label for="role_id" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.roles') }}</label>
                    <select id="role_id" name="role_id" class="input-field">
                        <option value="">{{ __('ui.roles') }}: {{ __('ui.all') }}</option>
                        @foreach(($roles ?? []) as $role)
                            <option value="{{ $role->id }}" {{ (string)($roleId ?? '') === (string)$role->id ? 'selected' : '' }}>
                                {{ $role->name }}
                            </option>
                        @endforeach
                    </select>
                </div>
                <div class="md:col-span-3 flex gap-3">
                    <button type="submit" class="btn-primary">{{ __('ui.search') }}</button>
                    <a href="{{ route('users.index') }}" class="btn-secondary">{{ __('ui.cancel') }}</a>
                </div>
            </form>

            @if($users->count())
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="text-left border-b border-slate-700">
                            <tr>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.name') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.email') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.roles') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.actions') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @foreach($users as $user)
                                <tr>
                                    <td class="py-4 text-slate-200">{{ $user->name }}</td>
                                    <td class="py-4 text-slate-300">{{ $user->email }}</td>
                                    <td class="py-4 text-slate-300">
                                        {{ $user->roles->pluck('name')->join(', ') ?: '-' }}
                                    </td>
                                    <td class="py-4">
                                        <div class="flex items-center gap-2">
                                            <a href="{{ route('users.edit', $user) }}" class="btn-secondary px-3 py-1 text-sm">
                                                {{ __('ui.edit') }}
                                            </a>
                                            <form method="POST" action="{{ route('users.destroy', $user) }}" onsubmit="return confirm('{{ __('ui.messages.confirm_delete') }}')">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn-danger px-3 py-1 text-sm">
                                                    {{ __('ui.delete') }}
                                                </button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
                <div class="mt-6">
                    {{ $users->links() }}
                </div>
            @else
                <p class="text-slate-400">{{ __('ui.no_users') }}</p>
            @endif
        </div>
    </div>
</x-layouts.app>
