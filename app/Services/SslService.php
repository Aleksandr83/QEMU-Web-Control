<?php

namespace App\Services;

class SslService
{
    private string $certFile;
    private string $keyFile;

    public function __construct()
    {
        $this->certFile = base_path('docker/nginx/ssl/server.crt');
        $this->keyFile = base_path('docker/nginx/ssl/server.key');
    }

    public function generateSelfSigned(string $domain = 'localhost'): array
    {
        try {
            $dn = [
                'countryName' => 'RU',
                'stateOrProvinceName' => 'Moscow',
                'localityName' => 'Moscow',
                'organizationName' => 'QEMU Web Control',
                'commonName' => $domain,
            ];

            $privateKey = openssl_pkey_new([
                'private_key_bits' => 2048,
                'private_key_type' => OPENSSL_KEYTYPE_RSA,
            ]);

            $csr = openssl_csr_new($dn, $privateKey, ['digest_alg' => 'sha256']);
            $cert = openssl_csr_sign($csr, null, $privateKey, 365, ['digest_alg' => 'sha256']);

            openssl_x509_export($cert, $certOut);
            openssl_pkey_export($privateKey, $keyOut);

            $dir = dirname($this->certFile);
            if (!is_dir($dir)) {
                mkdir($dir, 0755, true);
            }

            file_put_contents($this->certFile, $certOut);
            file_put_contents($this->keyFile, $keyOut);

            chmod($this->keyFile, 0600);

            return ['success' => true, 'message' => 'Certificate generated successfully'];
        } catch (\Exception $e) {
            return ['success' => false, 'message' => $e->getMessage()];
        }
    }

    public function getCertificateInfo(): ?array
    {
        if (!file_exists($this->certFile)) {
            return null;
        }

        $cert = openssl_x509_read(file_get_contents($this->certFile));
        if (!$cert) {
            return null;
        }

        $certData = openssl_x509_parse($cert);
        $validTo = $certData['validTo_time_t'];
        $daysRemaining = floor(($validTo - time()) / 86400);

        return [
            'subject' => $certData['subject']['CN'] ?? 'Unknown',
            'valid_from' => date('Y-m-d', $certData['validFrom_time_t']),
            'valid_to' => date('Y-m-d', $validTo),
            'days_remaining' => $daysRemaining,
        ];
    }

    public function certificateExists(): bool
    {
        return file_exists($this->certFile) && file_exists($this->keyFile);
    }
}
