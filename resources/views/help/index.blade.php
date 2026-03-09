<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
            <h1 class="text-3xl font-bold text-white">{{ __('ui.help.title') }}</h1>
            <p class="text-slate-400 mt-1">{{ __('ui.help.subtitle') }}</p>
        </div>

        <div class="card">
            <h2 class="text-lg font-semibold text-white mb-4">{{ __('ui.help.documentation') }}</h2>
            <ul class="space-y-3">
                @foreach($docs as $key => [$file, $label])
                    <li>
                        <a href="{{ route('help.doc', ['lang' => $lang, 'file' => $file]) }}" class="text-cyan-400 hover:text-cyan-300 hover:underline flex items-center gap-2">
                            <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
                            {{ $label }}
                        </a>
                    </li>
                @endforeach
            </ul>
            <div class="mt-6 pt-4 border-t border-slate-700">
                <p class="text-slate-300 font-medium mb-2">{{ __('ui.help.ai_tools_heading') }}</p>
                <p class="pl-4">
                    <a href="https://cursor.com/home" target="_blank" rel="noopener noreferrer" class="text-cyan-400 hover:text-cyan-300 hover:underline">{{ __('ui.help.cursor_ai') }}</a>
                </p>
            </div>
            <div class="mt-6 pt-4 border-t border-slate-700">
                <a href="https://github.com/Aleksandr83/QemuWebControl" target="_blank" rel="noopener noreferrer" class="text-cyan-400 hover:text-cyan-300 hover:underline flex items-center gap-2">
                    <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
                    {{ __('ui.help.project_link') }}
                </a>
            </div>
        </div>
    </div>
</x-layouts.app>
