<x-layouts.app>
    <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.group.edit') }}</h1>
        </div>

        <div class="card">
            <form method="POST" action="{{ route('groups.update', $group) }}" class="space-y-6">
                @csrf
                @method('PUT')
                <div>
                    <label for="name" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.name') }}</label>
                    <input id="name" name="name" type="text" class="input-field" value="{{ old('name', $group->name) }}" required>
                    @error('name')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                </div>
                <div>
                    <label class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.group.members') }}</label>
                    <div class="max-h-60 overflow-y-auto border border-slate-600 rounded-lg p-3 bg-slate-800/50 space-y-2">
                        @foreach($users as $u)
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input type="checkbox" name="user_ids[]" value="{{ $u->id }}"
                                    {{ in_array($u->id, old('user_ids', $group->users->pluck('id')->all())) ? 'checked' : '' }}
                                    class="rounded border-slate-600 text-cyan-500">
                                <span class="text-slate-300">{{ $u->name }}</span>
                                <span class="text-slate-500 text-sm">({{ $u->email }})</span>
                            </label>
                        @endforeach
                    </div>
                </div>
                <div class="flex justify-end gap-4">
                    <a href="{{ route('groups.index') }}" class="btn-secondary">{{ __('ui.cancel') }}</a>
                    <button type="submit" class="btn-primary">{{ __('ui.save') }}</button>
                </div>
            </form>
        </div>
    </div>
</x-layouts.app>
