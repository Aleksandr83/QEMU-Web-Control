<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Application;

trait CreatesApplication
{
    public function createApplication(): Application
    {
        $app = require __DIR__ . '/../bootstrap/app.php';

        $testStorage = sys_get_temp_dir() . '/laravel-test-storage-' . get_current_user();
        foreach (['logs', 'framework/cache', 'framework/sessions', 'framework/views', 'app/public', 'app/boot-media'] as $dir) {
            $path = $testStorage . '/' . $dir;
            if (!is_dir($path)) {
                mkdir($path, 0777, true);
            }
        }
        $app->useStoragePath($testStorage);

        $app->make(Kernel::class)->bootstrap();

        return $app;
    }
}
