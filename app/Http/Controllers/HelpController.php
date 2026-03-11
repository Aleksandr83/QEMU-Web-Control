<?php

namespace App\Http\Controllers;

use Illuminate\View\View;
use League\CommonMark\CommonMarkConverter;

class HelpController extends Controller
{
    private const ALLOWED_DOCS = [
        'INSTALL.EN.md', 'INSTALL.RU.md', 'INSTALL-EXAMPLE.EN.md', 'INSTALL-EXAMPLE.RU.md',
        'COMMANDS.EN.md', 'COMMANDS.RU.md', 'TROUBLESHOOTING.EN.md', 'TROUBLESHOOTING.RU.md',
        'CHANGELOG.EN.md', 'CHANGELOG.RU.md', 'AUTOSTART.EN.md', 'AUTOSTART.RU.md',
        'RISCV.EN.md', 'RISCV.RU.md', 'RISCV-QUICKSTART.EN.md', 'RISCV-QUICKSTART.RU.md',
        'APACHE.EN.md', 'APACHE.RU.md', 'DATABASE-TROUBLESHOOTING.EN.md', 'DATABASE-TROUBLESHOOTING.RU.md',
        'HOST-NETWORK-MODE.EN.md', 'HOST-NETWORK-MODE.RU.md',
        'PORT-CONFLICT-HANDLING.EN.md', 'PORT-CONFLICT-HANDLING.RU.md',
        'AUTHORS.EN.md', 'AUTHORS.RU.md',
        'BOOT-MEDIA.EN.md', 'BOOT-MEDIA.RU.md',
    ];

    public function index(): View
    {
        $locale = app()->getLocale();
        $lang = ($locale === 'ru') ? 'RU' : 'EN';
        $docs = [
            'install' => ['INSTALL.' . $lang . '.md', __('ui.help.install')],
            'commands' => ['COMMANDS.' . $lang . '.md', __('ui.help.commands')],
            'troubleshooting' => ['TROUBLESHOOTING.' . $lang . '.md', __('ui.help.troubleshooting')],
            'riscv' => ['RISCV.' . $lang . '.md', __('ui.help.riscv')],
            'apache' => ['APACHE.' . $lang . '.md', __('ui.help.apache')],
            'changelog' => ['CHANGELOG.' . $lang . '.md', __('ui.help.changelog')],
            'authors' => ['AUTHORS.' . $lang . '.md', __('ui.help.authors')],
            'boot_media' => ['BOOT-MEDIA.' . $lang . '.md', __('ui.help.boot_media')],
        ];

        $version = $this->resolveVersion($lang);

        return view('help.index', compact('docs', 'lang', 'version'));
    }

    private function resolveVersion(string $lang): string
    {
        $changelogPath = base_path('docs/' . $lang . '/CHANGELOG.' . $lang . '.md');
        if (!is_readable($changelogPath)) {
            return '';
        }

        $handle = fopen($changelogPath, 'r');
        while ($handle && ($line = fgets($handle)) !== false) {
            if (preg_match('/^##\s+\[([^\]]+)\]/', $line, $matches)) {
                fclose($handle);
                return $matches[1];
            }
        }
        if ($handle) {
            fclose($handle);
        }

        return '';
    }

    public function doc(string $lang, string $file): View
    {
        if (!in_array($file, self::ALLOWED_DOCS, true) || !in_array($lang, ['EN', 'RU'], true)) {
            abort(404);
        }

        $path = base_path('docs/' . $lang . '/' . $file);
        if (!is_readable($path)) {
            abort(404);
        }

        $markdown = file_get_contents($path);
        $converter = new CommonMarkConverter();
        $html = $converter->convert($markdown)->getContent();

        $title = pathinfo($file, PATHINFO_FILENAME);

        return view('help.doc', compact('html', 'title', 'lang'));
    }
}
