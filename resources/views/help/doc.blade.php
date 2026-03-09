<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6">
            <a href="{{ route('help.index') }}" class="text-slate-400 hover:text-white transition-all inline-flex items-center gap-1 text-sm">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/></svg>
                {{ __('ui.back') }}
            </a>
        </div>

        <div class="card doc-content w-full">
            {!! $html !!}
        </div>
    </div>
</x-layouts.app>
