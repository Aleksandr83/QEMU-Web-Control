<x-layouts.app>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6 flex justify-between items-start">
            <div>
                <h1 class="text-3xl font-bold text-white">{{ __('ui.certificates.title') }}</h1>
                <p class="text-slate-400 mt-1">{{ __('ui.certificates.subtitle') }}</p>
            </div>
            <a href="{{ route('activity-logs.index') }}" class="btn-secondary">{{ __('ui.back') }}</a>
        </div>

        @if($certInfo)
            <div class="card mb-6">
                <div class="flex flex-wrap gap-x-8 gap-y-2 text-sm">
                    <span class="text-slate-400">{{ __('ui.certificates.subject') }}:</span>
                    <span class="text-slate-200">{{ $certInfo['subject'] }}</span>
                    <span class="text-slate-600">|</span>
                    <span class="text-slate-400">{{ __('ui.certificates.valid_to') }}:</span>
                    <span class="text-slate-200">{{ $certInfo['valid_to'] }}</span>
                    <span class="text-slate-600">|</span>
                    <span class="text-slate-400">{{ __('ui.certificates.days_left') }}:</span>
                    <span class="{{ $certInfo['days_left'] < 30 ? 'text-amber-400' : 'text-slate-200' }}">{{ $certInfo['days_left'] }}</span>
                </div>
            </div>
        @else
            <div class="card mb-6 py-3">
                <p class="text-slate-400 text-sm">{{ __('ui.certificates.no_cert') }}</p>
            </div>
        @endif

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="card">
                <div class="flex items-center gap-3 mb-4">
                    <div class="w-10 h-10 bg-cyan-500/20 rounded-lg flex items-center justify-center shrink-0">
                        <svg class="w-5 h-5 text-cyan-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>
                    </div>
                    <h2 class="text-lg font-semibold text-white">{{ __('ui.certificates.upload') }}</h2>
                </div>
                <form method="POST" action="{{ route('certificates.store') }}" enctype="multipart/form-data" class="space-y-3">
                    @csrf
                    <input id="certificate" name="certificate" type="file" class="block w-full text-sm text-slate-300 file:mr-2 file:py-1.5 file:px-3 file:rounded file:border-0 file:bg-slate-700 file:text-slate-200 file:text-xs" accept=".crt,.pem" required>
                    @error('certificate')<p class="text-sm text-red-400">{{ $message }}</p>@enderror
                    <details class="text-slate-500 text-xs">
                        <summary class="cursor-pointer hover:text-slate-400">{{ __('ui.certificates.key_optional') }}</summary>
                        <input id="private_key" name="private_key" type="file" class="block w-full mt-2 text-sm text-slate-300 file:mr-2 file:py-1.5 file:px-3 file:rounded file:border-0 file:bg-slate-700 file:text-slate-200 file:text-xs" accept=".key,.pem">
                    </details>
                    @error('private_key')<p class="text-sm text-red-400">{{ $message }}</p>@enderror
                    <button type="submit" class="btn-primary w-full text-sm">{{ __('ui.certificates.upload_btn') }}</button>
                </form>
            </div>

            <div class="card">
                <div class="flex items-center gap-3 mb-4">
                    <div class="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center shrink-0">
                        <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
                    </div>
                    <h2 class="text-lg font-semibold text-white">{{ __('ui.certificates.letsencrypt') }}</h2>
                </div>
                <p class="text-slate-500 text-xs mb-3">{{ __('ui.certificates.letsencrypt_desc') }}</p>
                <form method="POST" action="{{ route('certificates.store') }}" class="space-y-3">
                    @csrf
                    <input id="letsencrypt_domain" name="letsencrypt_domain" type="text" class="input-field text-sm" placeholder="qemu.example.com" value="{{ old('letsencrypt_domain') }}">
                    @error('letsencrypt_domain')<p class="text-sm text-red-400">{{ $message }}</p>@enderror
                    <button type="submit" class="btn-primary w-full text-sm">{{ __('ui.certificates.letsencrypt_import_btn') }}</button>
                </form>
                <p class="text-slate-600 text-xs mt-3">{{ __('ui.certificates.letsencrypt_auto_renew') }}</p>
            </div>

            <div class="card">
                <div class="flex items-center gap-3 mb-4">
                    <div class="w-10 h-10 bg-slate-500/20 rounded-lg flex items-center justify-center shrink-0">
                        <svg class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    </div>
                    <h2 class="text-lg font-semibold text-white">{{ __('ui.certificates.generate') }}</h2>
                </div>
                <p class="text-slate-500 text-xs mb-4">{{ __('ui.certificates.generate_desc') }}</p>
                <form method="POST" action="{{ route('certificates.store') }}">
                    @csrf
                    <input type="hidden" name="generate" value="1">
                    <button type="submit" class="btn-secondary w-full text-sm">{{ __('ui.certificates.generate_btn') }}</button>
                </form>
            </div>
        </div>

        <p class="text-slate-500 text-sm mt-6">{{ __('ui.certificates.restart_hint') }}</p>
    </div>
</x-layouts.app>
