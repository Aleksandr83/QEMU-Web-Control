<?php

namespace App\Console\Commands;

use App\Models\ActivityLog;
use App\Models\Setting;
use Illuminate\Console\Command;

class RenewLetsEncryptCommand extends Command
{
    protected $signature = 'certificates:renew';

    protected $description = 'Copy Let\'s Encrypt certificates to nginx ssl dir (run after certbot renew)';

    public function handle(): int
    {
        $domain = Setting::get('letsencrypt_domain') ?? config('app.letsencrypt_domain');
        if (empty($domain)) {
            $this->warn('Let\'s Encrypt domain not configured. Set LETSENCRYPT_DOMAIN in .env or import certificate first.');
            return self::SUCCESS;
        }

        $domain = trim(preg_replace('/[^a-zA-Z0-9.\-]/', '', $domain));
        if ($domain === '') {
            return self::FAILURE;
        }

        $fullchain = '/etc/letsencrypt/live/' . $domain . '/fullchain.pem';
        $privkey = '/etc/letsencrypt/live/' . $domain . '/privkey.pem';

        if (!is_readable($fullchain) || !is_readable($privkey)) {
            $this->error("Certificate not found for domain: {$domain}");
            return self::FAILURE;
        }

        $sslDir = base_path('docker/nginx/ssl');
        $certPath = $sslDir . '/server.crt';
        $keyPath = $sslDir . '/server.key';

        if (!is_dir($sslDir)) {
            mkdir($sslDir, 0755, true);
        }

        if (file_put_contents($certPath, file_get_contents($fullchain)) === false ||
            file_put_contents($keyPath, file_get_contents($privkey)) === false) {
            $this->error('Failed to copy certificate files');
            return self::FAILURE;
        }

        chmod($keyPath, 0600);

        ActivityLog::log(ActivityLog::TYPE_CERTIFICATE, ActivityLog::ACTION_UPDATE, null, null, 'HTTPS certificate', null, ['source' => 'letsencrypt-renew', 'domain' => $domain]);

        $this->info("Certificate for {$domain} copied successfully. Reload nginx: docker compose exec nginx nginx -s reload");

        return self::SUCCESS;
    }
}
