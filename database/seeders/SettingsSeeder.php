<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

class SettingsSeeder extends Seeder
{
    public function run(): void
    {
        $serverId = Setting::serverId();
        if ($serverId === null) {
            return;
        }

        Setting::set('DefaultHddPathPrefix', '/var/qemu/VM/');
    }
}
