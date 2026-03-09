<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Session;
use Symfony\Component\HttpFoundation\Response;

class SetLocaleMiddleware
{
    protected array $availableLocales = ['en', 'ru'];

    public function handle(Request $request, Closure $next): Response
    {
        $locale = $this->determineLocale($request);
        App::setLocale($locale);
        
        return $next($request);
    }

    protected function determineLocale(Request $request): string
    {
        if ($request->user() && $request->user()->locale) {
            return $this->validateLocale($request->user()->locale);
        }

        if (Session::has('locale')) {
            return $this->validateLocale(Session::get('locale'));
        }

        if ($request->hasCookie('locale')) {
            return $this->validateLocale($request->cookie('locale'));
        }

        return config('app.locale', 'en');
    }

    protected function validateLocale(string $locale): string
    {
        return in_array($locale, $this->availableLocales) ? $locale : 'en';
    }
}
