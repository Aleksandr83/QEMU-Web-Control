#!/bin/bash
# Certbot deploy hook: copy renewed Let's Encrypt certs to nginx and reload
# Usage: add to crontab: 0 3 * * * certbot renew --quiet --deploy-hook "/path/to/QemuWebControl/scripts/renew-letsencrypt-deploy-hook.sh"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SSL_DIR="${PROJECT_DIR}/docker/nginx/ssl"

DOMAIN="${CERTBOT_DOMAIN:-}"
if [ -z "$DOMAIN" ]; then
    echo "CERTBOT_DOMAIN not set" >&2
    exit 1
fi

FULLCHAIN="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
PRIVKEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

if [ ! -f "$FULLCHAIN" ] || [ ! -f "$PRIVKEY" ]; then
    echo "Certificate files not found for ${DOMAIN}" >&2
    exit 1
fi

mkdir -p "$SSL_DIR"
cp "$FULLCHAIN" "${SSL_DIR}/server.crt"
cp "$PRIVKEY" "${SSL_DIR}/server.key"
chmod 600 "${SSL_DIR}/server.key"

cd "$PROJECT_DIR"
if command -v docker >/dev/null 2>&1; then
    docker compose exec -T nginx nginx -s reload 2>/dev/null || docker-compose exec -T nginx nginx -s reload 2>/dev/null || true
fi

echo "Let's Encrypt certificate for ${DOMAIN} renewed and nginx reloaded"
