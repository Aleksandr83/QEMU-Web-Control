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
    <nav class="bg-slate-800/50 backdrop-blur-sm border-b border-slate-700/50">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between h-16">
                <div class="flex items-center">
                    <a href="/" class="flex items-center space-x-3">
                        <div class="w-10 h-10 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-xl flex items-center justify-center">
                            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
                            </svg>
                        </div>
                        <span class="text-xl font-bold text-white">QEMU Control</span>
                    </a>
                </div>

                <div class="flex items-center space-x-2 text-sm">
                    <a href="{{ route('language.switch', 'en') }}" class="px-2 py-1 rounded {{ app()->getLocale() === 'en' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                        EN
                    </a>
                    <span class="text-slate-600">|</span>
                    <a href="{{ route('language.switch', 'ru') }}" class="px-2 py-1 rounded {{ app()->getLocale() === 'ru' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                        RU
                    </a>
                </div>
            </div>
        </div>
    </nav>

    <main class="flex-grow flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
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
        try { localStorage.removeItem('vnc_cert_warning_dismissed'); } catch (e) {}
    </script>
</body>
</html>
