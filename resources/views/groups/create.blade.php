<x-layouts.app>
    <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.group.create') }}</h1>
        </div>

        <div class="card">
            <form method="POST" action="{{ route('groups.store') }}" class="space-y-6">
                @csrf
                <div>
                    <label for="name" class="block text-sm font-medium text-slate-300 mb-2">{{ __('ui.name') }}</label>
                    <input id="name" name="name" type="text" class="input-field" value="{{ old('name') }}" required>
                    @error('name')<p class="mt-1 text-sm text-red-400">{{ $message }}</p>@enderror
                </div>
                <div class="flex justify-end gap-4">
                    <a href="{{ route('groups.index') }}" class="btn-secondary">{{ __('ui.cancel') }}</a>
                    <button type="submit" class="btn-primary">{{ __('ui.save') }}</button>
                </div>
            </form>
        </div>
    </div>
</x-layouts.app>
