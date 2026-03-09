<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class ProcessBootMediaDeletions extends Command
{
    protected $signature = 'boot-media:process-deletions';

    protected $description = 'Process queued Boot Media ISO delete requests';

    public function handle(): int
    {
        $file = storage_path('app/boot-media/delete-requests.json');
        if (!is_file($file)) {
            return 0;
        }

        $lock = $file . '.lock';
        $fp = fopen($lock, 'c');
        if (!flock($fp, LOCK_EX | LOCK_NB)) {
            fclose($fp);
            return 0;
        }

        $content = File::get($file);
        File::put($file, '[]');

        $requests = json_decode($content, true);
        if (!is_array($requests)) {
            flock($fp, LOCK_UN);
            fclose($fp);
            return 0;
        }

        foreach ($requests as $req) {
            $path = $req['path'] ?? null;
            if ($path && is_file($path) && str_ends_with(strtolower($path), '.iso')) {
                @unlink($path);
            }
        }

        flock($fp, LOCK_UN);
        fclose($fp);

        return 0;
    }
}
