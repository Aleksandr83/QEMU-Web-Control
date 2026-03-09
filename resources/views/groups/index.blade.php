<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8 flex justify-between items-center">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.groups') }}</h1>
            <a href="{{ route('groups.create') }}" class="btn-primary">
                {{ __('ui.group.create') }}
            </a>
        </div>

        <div class="card">
            @if($groups->count())
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead class="text-left border-b border-slate-700">
                            <tr>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.name') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.group.users_count') }}</th>
                                <th class="pb-3 text-slate-400 font-medium">{{ __('ui.actions') }}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-700/50">
                            @foreach($groups as $group)
                                <tr>
                                    <td class="py-4 text-slate-200">{{ $group->name }}</td>
                                    <td class="py-4 text-slate-300">{{ $group->users_count }}</td>
                                    <td class="py-4">
                                        <a href="{{ route('groups.edit', $group) }}" class="btn-secondary px-3 py-1 text-sm">
                                            {{ __('ui.edit') }}
                                        </a>
                                        <form method="POST" action="{{ route('groups.destroy', $group) }}" class="inline ml-2" onsubmit="return confirm('{{ __('ui.messages.confirm_delete') }}')">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn-danger px-3 py-1 text-sm">
                                                {{ __('ui.delete') }}
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
                <div class="mt-6">{{ $groups->links() }}</div>
            @else
                <p class="text-slate-400 py-8 text-center">{{ __('ui.group.no_groups') }}</p>
            @endif
        </div>
    </div>
</x-layouts.app>
