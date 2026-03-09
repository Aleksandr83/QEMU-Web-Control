<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ config('app.name', 'QEMU Web Control') }}</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen flex flex-col bg-slate-900">
    <nav class="bg-slate-800/50 backdrop-blur-sm border-b border-slate-700/50 sticky top-0 z-50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <a href="{{ route('dashboard') }}" class="flex items-center space-x-3">
                        <div class="w-10 h-10 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-xl flex items-center justify-center">
                            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
                            </svg>
                        </div>
                        <span class="text-xl font-bold text-white">QEMU Web Control</span>
                    </a>
                    
                    <div class="hidden md:flex ml-10 space-x-4">
                        <a href="{{ route('dashboard') }}" class="px-3 py-2 rounded-lg text-sm font-medium {{ request()->routeIs('dashboard') ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all">
                            {{ __('ui.dashboard') }}
                        </a>
                        <a href="{{ route('vms.index') }}" class="px-3 py-2 rounded-lg text-sm font-medium {{ request()->routeIs('vms.*') ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all">
                            {{ __('ui.virtual_machines') }}
                        </a>
                        @if (Auth::user()->isAdmin())
                            <div class="relative group/settings">
                                <a href="{{ route('activity-logs.index') }}" class="px-3 py-2 rounded-lg text-sm font-medium {{ request()->routeIs('users.*') || request()->routeIs('groups.*') || request()->routeIs('activity-logs.*') || request()->routeIs('certificates.*') || request()->routeIs('boot-media.*') ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all flex items-center gap-1">
                                    {{ __('ui.settings') }}
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
                                </a>
                                <div class="absolute left-0 mt-1 py-1 w-72 bg-slate-800 border border-slate-600 rounded-lg shadow-xl opacity-0 invisible group-hover/settings:opacity-100 group-hover/settings:visible transition-all z-50">
                                    <a href="{{ route('activity-logs.index') }}" class="block px-4 py-2 text-sm {{ request()->routeIs('activity-logs.*') ? 'text-cyan-400 bg-slate-700/50' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} rounded-md">
                                        {{ __('ui.logs') }}
                                    </a>
                                    <a href="{{ route('users.index') }}" class="block px-4 py-2 text-sm {{ request()->routeIs('users.*') ? 'text-cyan-400 bg-slate-700/50' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} rounded-md">
                                        {{ __('ui.users') }}
                                    </a>
                                    <a href="{{ route('groups.index') }}" class="block px-4 py-2 text-sm {{ request()->routeIs('groups.*') ? 'text-cyan-400 bg-slate-700/50' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} rounded-md">
                                        {{ __('ui.groups') }}
                                    </a>
                                    <a href="{{ route('boot-media.index') }}" class="block px-4 py-2 text-sm {{ request()->routeIs('boot-media.*') ? 'text-cyan-400 bg-slate-700/50' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} rounded-md">
                                        {{ __('ui.boot_media.menu') }}
                                    </a>
                                    <a href="{{ route('certificates.index') }}" class="block px-4 py-2 text-sm {{ request()->routeIs('certificates.*') ? 'text-cyan-400 bg-slate-700/50' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} rounded-md">
                                        {{ __('ui.certificates.menu') }}
                                    </a>
                                </div>
                            </div>
                        @endif
                            <a href="{{ route('help.index') }}" class="px-3 py-2 rounded-lg text-sm font-medium {{ request()->routeIs('help.*') ? 'text-white bg-slate-700' : 'text-slate-300 hover:text-white hover:bg-slate-700/50' }} transition-all">
                                {{ __('ui.help.menu') }}
                            </a>
                    </div>
                </div>

                <div class="flex items-center space-x-4">
                    <div class="flex items-center space-x-2 text-sm">
                        <a href="{{ route('language.switch', 'en') }}" class="px-2 py-1 rounded {{ app()->getLocale() === 'en' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                            EN
                        </a>
                        <span class="text-slate-600">|</span>
                        <a href="{{ route('language.switch', 'ru') }}" class="px-2 py-1 rounded {{ app()->getLocale() === 'ru' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                            RU
                        </a>
                    </div>

                    <div class="relative" id="user-menu-wrap">
                        <button type="button" id="user-menu-btn" class="px-3 py-2 rounded-lg text-sm font-medium text-slate-300 hover:text-white hover:bg-slate-700/50 transition-all flex items-center gap-1">
                            {{ Auth::user()->name }}
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
                        </button>
                        <div id="user-menu-dropdown" class="absolute right-0 mt-1 py-1 w-48 bg-slate-800 border border-slate-600 rounded-lg shadow-xl opacity-0 invisible transition-all z-50">
                            <form method="POST" action="{{ route('logout') }}" class="block">
                                @csrf
                                <button type="submit" class="w-full text-left flex items-center gap-2 px-4 py-2 text-sm text-slate-300 hover:text-white hover:bg-slate-700/50 rounded-md">
                                    <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                                    {{ __('ui.logout') }}
                                </button>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </nav>

    <main class="flex-grow">
        @if (session('success'))
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-4">
                <div class="bg-green-500/20 border border-green-500/50 text-green-400 px-4 py-3 rounded-xl">
                    {{ session('success') }}
                </div>
            </div>
        @endif

        @if (session('error'))
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-4">
                <div class="bg-red-500/20 border border-red-500/50 text-red-400 px-4 py-3 rounded-xl">
                    {{ session('error') }}
                </div>
            </div>
        @endif

        {{ $slot }}
    </main>

    <footer class="mt-auto bg-slate-800/30 border-t border-slate-700/50 py-6">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center text-slate-400 text-sm">
                <p>&copy; {{ date('Y') }} QEMU Web Control. All rights reserved.</p>
            </div>
        </div>
    </footer>
    <script>
        (function() {
            var wrap = document.getElementById('user-menu-wrap');
            var btn = document.getElementById('user-menu-btn');
            var dropdown = document.getElementById('user-menu-dropdown');
            if (!wrap || !btn || !dropdown) return;
            btn.addEventListener('click', function(e) {
                e.stopPropagation();
                var open = dropdown.classList.contains('opacity-100');
                dropdown.classList.toggle('opacity-0', open);
                dropdown.classList.toggle('invisible', open);
                dropdown.classList.toggle('opacity-100', !open);
                dropdown.classList.toggle('visible', !open);
            });
            document.addEventListener('click', function(e) {
                if (wrap.contains(e.target)) return;
                dropdown.classList.add('opacity-0', 'invisible');
                dropdown.classList.remove('opacity-100', 'visible');
            });
        })();
    </script>
</body>
</html>
