<?php

namespace App\Http\Controllers;

use App\Models\ActivityLog;
use App\Models\Setting;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class CertificateController extends Controller
{
    private function parseCombinedPem(string $content): ?array
    {
        $cert = null;
        $key = null;
        if (preg_match('/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/s', $content, $m)) {
            $cert = trim($m[0]);
        }
        if (preg_match('/-----BEGIN (?:RSA |EC )?PRIVATE KEY-----.*?-----END (?:RSA |EC )?PRIVATE KEY-----/s', $content, $m)) {
            $key = trim($m[0]);
        }
        if ($cert !== null && $key !== null) {
            return ['cert' => $cert, 'key' => $key];
        }
        return null;
    }

    private function sslPath(): string
    {
        return base_path('docker/nginx/ssl');
    }

    private function certPath(): string
    {
        return $this->sslPath() . '/server.crt';
    }

    private function keyPath(): string
    {
        return $this->sslPath() . '/server.key';
    }

    public function index(): View
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        $certInfo = null;
        $certPath = $this->certPath();
        $keyPath = $this->keyPath();

        if (file_exists($certPath) && is_readable($certPath)) {
            $certData = @file_get_contents($certPath);
            if ($certData !== false) {
                $parsed = @openssl_x509_parse($certData);
                if (is_array($parsed)) {
                    $certInfo = [
                        'subject' => $parsed['subject']['CN'] ?? ($parsed['subject']['commonName'] ?? '—'),
                        'issuer' => $parsed['issuer']['CN'] ?? ($parsed['issuer']['O'] ?? '—'),
                        'valid_from' => isset($parsed['validFrom_time_t']) ? date('Y-m-d H:i', $parsed['validFrom_time_t']) : '—',
                        'valid_to' => isset($parsed['validTo_time_t']) ? date('Y-m-d H:i', $parsed['validTo_time_t']) : '—',
                        'days_left' => isset($parsed['validTo_time_t']) ? max(0, (int) (($parsed['validTo_time_t'] - time()) / 86400)) : null,
                    ];
                }
            }
        }

        return view('certificates.index', compact('certInfo'));
    }

    public function store(Request $request): RedirectResponse
    {
        abort_unless(auth()->user()?->isAdmin(), 403);

        if ($request->has('generate')) {
            return $this->generateSelfSigned();
        }

        if ($request->has('letsencrypt_domain')) {
            return $this->importLetsEncrypt($request->input('letsencrypt_domain'));
        }

        $request->validate([
            'certificate' => 'required|file|mimes:crt,pem',
            'private_key' => 'nullable|file',
        ]);

        $certFile = $request->file('certificate');
        $keyFile = $request->file('private_key');
        $certContent = $certFile->get();
        $keyContent = $keyFile?->get();

        if (empty($keyContent)) {
            $parsed = $this->parseCombinedPem($certContent);
            if ($parsed === null) {
                return back()->withInput()->with('error', __('ui.certificates.need_combined_or_key'));
            }
            $certContent = $parsed['cert'];
            $keyContent = $parsed['key'];
        }

        $keyResource = @openssl_pkey_get_private($keyContent);
        if ($keyResource === false) {
            return back()->withInput()->with('error', __('ui.certificates.invalid_key'));
        }

        $certResource = @openssl_x509_read($certContent);
        if ($certResource === false) {
            openssl_free_key($keyResource);
            return back()->withInput()->with('error', __('ui.certificates.invalid_cert'));
        }

        if (!openssl_x509_check_private_key($certResource, $keyResource)) {
            openssl_free_key($keyResource);
            openssl_x509_free($certResource);
            return back()->withInput()->with('error', __('ui.certificates.invalid_key'));
        }
        openssl_free_key($keyResource);
        openssl_x509_free($certResource);

        $sslDir = $this->sslPath();
        if (!is_dir($sslDir)) {
            mkdir($sslDir, 0755, true);
        }

        if (file_put_contents($this->certPath(), $certContent) === false || file_put_contents($this->keyPath(), $keyContent) === false) {
            return back()->with('error', __('ui.certificates.save_failed'));
        }

        chmod($this->keyPath(), 0600);

        ActivityLog::log(ActivityLog::TYPE_CERTIFICATE, ActivityLog::ACTION_UPDATE, null, null, 'HTTPS certificate', null, ['source' => 'upload']);

        return redirect()->route('certificates.index')
            ->with('success', __('ui.certificates.uploaded'));
    }

    private function generateSelfSigned(): RedirectResponse
    {
        $sslDir = $this->sslPath();
        if (!is_dir($sslDir)) {
            mkdir($sslDir, 0755, true);
        }

        $keyPath = $this->keyPath();
        $certPath = $this->certPath();

        $config = [
            'digest_alg' => 'sha256',
            'private_key_bits' => 2048,
            'private_key_type' => OPENSSL_KEYTYPE_RSA,
        ];

        $dn = [
            'countryName' => 'RU',
            'stateOrProvinceName' => 'N/A',
            'localityName' => 'N/A',
            'organizationName' => 'QEMU Web Control',
            'organizationalUnitName' => 'HTTPS',
            'commonName' => 'localhost',
            'emailAddress' => 'admin@localhost',
        ];

        $key = openssl_pkey_new($config);
        if ($key === false) {
            return back()->with('error', __('ui.certificates.generate_failed'));
        }

        $csr = openssl_csr_new($dn, $key, $config);
        if ($csr === false) {
            openssl_pkey_free($key);
            return back()->with('error', __('ui.certificates.generate_failed'));
        }

        $cert = openssl_csr_sign($csr, null, $key, 365, $config);
        openssl_csr_free($csr);

        if ($cert === false) {
            openssl_pkey_free($key);
            return back()->with('error', __('ui.certificates.generate_failed'));
        }

        openssl_x509_export_to_file($cert, $certPath);
        openssl_x509_free($cert);

        $keyPem = '';
        if (!openssl_pkey_export($key, $keyPem)) {
            openssl_pkey_free($key);
            return back()->with('error', __('ui.certificates.generate_failed'));
        }
        file_put_contents($keyPath, $keyPem);
        openssl_pkey_free($key);
        chmod($keyPath, 0600);

        ActivityLog::log(ActivityLog::TYPE_CERTIFICATE, ActivityLog::ACTION_UPDATE, null, null, 'HTTPS certificate', null, ['source' => 'self-signed']);

        return redirect()->route('certificates.index')
            ->with('success', __('ui.certificates.generated'));
    }

    private function importLetsEncrypt(string $domain): RedirectResponse
    {
        $domain = trim(preg_replace('/[^a-zA-Z0-9.\-]/', '', $domain));
        if ($domain === '') {
            return back()->with('error', __('ui.certificates.invalid_domain'));
        }

        $leBase = '/etc/letsencrypt/live/' . $domain;
        $fullchain = $leBase . '/fullchain.pem';
        $privkey = $leBase . '/privkey.pem';

        if (!is_readable($fullchain) || !is_readable($privkey)) {
            return back()->with('error', __('ui.certificates.letsencrypt_not_found', ['domain' => $domain]));
        }

        $certContent = file_get_contents($fullchain);
        $keyContent = file_get_contents($privkey);

        $keyResource = @openssl_pkey_get_private($keyContent);
        if ($keyResource === false) {
            return back()->with('error', __('ui.certificates.invalid_key'));
        }

        $certResource = @openssl_x509_read($certContent);
        if ($certResource === false) {
            openssl_free_key($keyResource);
            return back()->with('error', __('ui.certificates.invalid_cert'));
        }

        if (!openssl_x509_check_private_key($certResource, $keyResource)) {
            openssl_free_key($keyResource);
            openssl_x509_free($certResource);
            return back()->with('error', __('ui.certificates.invalid_key'));
        }
        openssl_free_key($keyResource);
        openssl_x509_free($certResource);

        $sslDir = $this->sslPath();
        if (!is_dir($sslDir)) {
            mkdir($sslDir, 0755, true);
        }

        if (file_put_contents($this->certPath(), $certContent) === false || file_put_contents($this->keyPath(), $keyContent) === false) {
            return back()->with('error', __('ui.certificates.save_failed'));
        }

        chmod($this->keyPath(), 0600);

        try {
            Setting::set('letsencrypt_domain', $domain);
        } catch (\Throwable $e) {
            // Server ID may not be set in some environments
        }

        ActivityLog::log(ActivityLog::TYPE_CERTIFICATE, ActivityLog::ACTION_UPDATE, null, null, 'HTTPS certificate', null, ['source' => 'letsencrypt', 'domain' => $domain]);

        return redirect()->route('certificates.index')
            ->with('success', __('ui.certificates.letsencrypt_imported'));
    }
}
