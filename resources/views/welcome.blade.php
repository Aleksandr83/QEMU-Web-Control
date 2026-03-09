<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>QEMU Web Control</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen flex flex-col bg-slate-900">
    <div class="flex-grow flex items-center justify-center px-4">
        <div class="text-center">
            <div class="w-20 h-20 bg-gradient-to-r from-cyan-500 to-blue-500 rounded-2xl flex items-center justify-center mx-auto mb-8">
                <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/>
                </svg>
            </div>
            
            <h1 class="text-5xl font-bold text-white mb-4">{{ __('ui.welcome_title') }}</h1>
            <p class="text-xl text-slate-400 mb-8">{{ __('ui.welcome_subtitle') }}</p>
            
            <div class="flex justify-center space-x-4">
                <a href="{{ route('login') }}" class="btn-primary">
                    {{ __('ui.login') }}
                </a>
            </div>

            <div class="mt-8 flex items-center justify-center space-x-2 text-sm">
                <a href="{{ route('language.switch', 'en') }}" class="px-3 py-1 rounded {{ app()->getLocale() === 'en' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                    EN
                </a>
                <span class="text-slate-600">|</span>
                <a href="{{ route('language.switch', 'ru') }}" class="px-3 py-1 rounded {{ app()->getLocale() === 'ru' ? 'text-white bg-slate-700' : 'text-slate-400 hover:text-white' }} transition-all">
                    RU
                </a>
            </div>
        </div>
    </div>

    <footer class="mt-auto bg-slate-800/30 border-t border-slate-700/50 py-6">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center text-slate-400 text-sm">
                <p>&copy; {{ date('Y') }} QEMU Web Control. All rights reserved.</p>
            </div>
        </div>
    </footer>
</body>
</html>
