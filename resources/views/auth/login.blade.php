<x-layouts.guest>
    <div class="w-full max-w-md">
        <div class="card">
            <div class="mb-6 text-center">
                <h2 class="text-3xl font-bold text-white mb-2">{{ __('ui.login') }}</h2>
                <p class="text-slate-400">{{ __('ui.dashboard') }}</p>
            </div>

            @if ($errors->any())
                <div class="mb-4 bg-red-500/20 border border-red-500/50 text-red-400 px-4 py-3 rounded-xl text-sm">
                    <ul class="list-disc list-inside">
                        @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                        @endforeach
                    </ul>
                </div>
            @endif

            <form method="POST" action="{{ route('login') }}" class="space-y-6">
                @csrf

                <div>
                    <label for="email" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.email') }}
                    </label>
                    <input id="email" type="text" name="email" value="{{ old('email') }}" required autofocus autocomplete="username"
                           class="input-field">
                </div>

                <div>
                    <label for="password" class="block text-sm font-medium text-slate-300 mb-2">
                        {{ __('ui.password') }}
                    </label>
                    <input id="password" type="password" name="password" required autocomplete="current-password"
                           class="input-field">
                </div>

                <div class="flex items-center">
                    <input id="remember" type="checkbox" name="remember" class="rounded bg-slate-700 border-slate-600 text-cyan-500 focus:ring-cyan-500">
                    <label for="remember" class="ml-2 text-sm text-slate-300">
                        {{ __('ui.remember_me') }}
                    </label>
                </div>

                <button type="submit" class="btn-primary w-full">
                    {{ __('ui.login') }}
                </button>
            </form>
        </div>
    </div>
</x-layouts.guest>
