<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Support\Facades\Session;

class LanguageController extends Controller
{
    protected array $availableLocales = ['en', 'ru'];

    public function switch(Request $request, string $locale): RedirectResponse
    {
        if (!in_array($locale, $this->availableLocales)) {
            $locale = 'en';
        }

        Session::put('locale', $locale);
        Cookie::queue('locale', $locale, 60 * 24 * 365);

        if ($request->user()) {
            $request->user()->update(['locale' => $locale]);
        }

        $previous = url()->previous();
        $newLang = ($locale === 'ru') ? 'RU' : 'EN';
        if (preg_match('#/help/docs/(EN|RU)/([a-zA-Z0-9_.-]+\.(EN|RU)\.md)$#', parse_url($previous, PHP_URL_PATH) ?? '', $m)) {
            $file = preg_replace('/\.(EN|RU)\.md$/', '.' . $newLang . '.md', $m[2]);
            return redirect()->route('help.doc', ['lang' => $newLang, 'file' => $file]);
        }

        return redirect()->to($previous ?: url('/'));
    }
}
