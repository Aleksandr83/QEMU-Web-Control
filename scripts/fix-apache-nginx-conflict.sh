#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

NO_RESTART=false
for arg in "$@"; do
    [ "$arg" = "--no-restart" ] && NO_RESTART=true
done

echo "Fix: Apache (80/443) + Docker nginx conflict"
echo "Switching to bridge mode - nginx will use APP_PORT/APP_SSL_PORT"
echo ""

[ ! -f .env ] && { echo "Error: .env not found"; exit 1; }

APP_PORT=$(grep -E '^APP_PORT=' .env | cut -d '=' -f2)
APP_SSL_PORT=$(grep -E '^APP_SSL_PORT=' .env | cut -d '=' -f2)
if [ "$APP_PORT" = "80" ] || [ "$APP_SSL_PORT" = "443" ]; then
    APP_PORT=8081
    APP_SSL_PORT=8444
fi
APP_PORT=${APP_PORT:-8081}
APP_SSL_PORT=${APP_SSL_PORT:-8444}

[ ! -f docker-compose.yml.backup ] && cp docker-compose.yml docker-compose.yml.backup

ARCH=$(uname -m)
USE_BACKUP=false
if [ -f docker-compose.yml.backup ] && ! grep -q 'network_mode.*host' docker-compose.yml.backup 2>/dev/null; then
    USE_BACKUP=true
fi

DB_HOST_VAL=$(grep -E '^DB_HOST=' .env | cut -d '=' -f2)

if [ "$ARCH" = "riscv64" ]; then
    if [ -f docker/docker-compose.riscv.yml ]; then
        cp docker/docker-compose.riscv.yml docker-compose.yml
        echo "RISC-V: using docker/docker-compose.riscv.yml (bridge mode, no DB container)"
    else
        echo "Error: docker/docker-compose.riscv.yml not found for RISC-V"
        exit 1
    fi
elif [ "$USE_BACKUP" = true ]; then
    if grep -q '^\s*db:' docker-compose.yml.backup 2>/dev/null && [ "$DB_HOST_VAL" != "db" ]; then
        if [ -f docker/docker-compose.riscv.yml ]; then
            cp docker/docker-compose.riscv.yml docker-compose.yml
            echo "Backup has DB container but DB_HOST=$DB_HOST_VAL (external) — using docker/docker-compose.riscv.yml (no DB container)"
        else
            cp docker-compose.yml.backup docker-compose.yml
            echo "Restored docker-compose.yml from backup (bridge mode)"
        fi
    else
        cp docker-compose.yml.backup docker-compose.yml
        echo "Restored docker-compose.yml from backup (bridge mode)"
    fi
elif grep -q 'network_mode.*host' docker-compose.yml 2>/dev/null; then
    cat > docker-compose.yml << 'COMPOSE'
services:
  app:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
      - ./docker/php/zz-docker.conf:/usr/local/etc/php-fpm.d/zz-docker.conf
    networks:
      - qemu_network
    environment:
      - DB_HOST=${DB_HOST}
      - DB_PORT=${DB_PORT}
      - DB_DATABASE=${DB_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}

  nginx:
    build:
      context: ./docker/nginx
      dockerfile: Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    restart: unless-stopped
    ports:
      - "${APP_PORT}:80"
      - "${APP_SSL_PORT}:443"
    volumes:
      - ./:/var/www
      - ./docker/nginx/conf.d:/etc/nginx/conf.d
      - ./docker/nginx/ssl:/etc/nginx/ssl
    networks:
      - qemu_network
    depends_on:
      - app

  scheduler:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_scheduler
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    networks:
      - qemu_network
    entrypoint: /bin/sh
    command: -c "while true; do php /var/www/artisan schedule:run --verbose --no-interaction; sleep 60; done"

networks:
  qemu_network:
    driver: bridge
COMPOSE
    echo "Created docker-compose.yml (bridge mode with ports)"
fi

if [ -f docker/nginx/conf.d/default.conf ] && grep -q 'fastcgi_pass 127.0.0.1' docker/nginx/conf.d/default.conf; then
    [ ! -f docker/nginx/conf.d/default.conf.bak ] && cp docker/nginx/conf.d/default.conf docker/nginx/conf.d/default.conf.bak
    sed -i 's|fastcgi_pass 127.0.0.1:9000|fastcgi_pass app:9000|g' docker/nginx/conf.d/default.conf
    echo "Updated nginx config: fastcgi_pass app:9000 (bridge mode)"
fi

GATEWAY_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1")
DB_HOST=$(grep -E '^DB_HOST=' .env | cut -d '=' -f2)
DB_CHANGED=false
if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
    sed -i "s|DB_HOST=.*|DB_HOST=$GATEWAY_IP|" .env
    echo "DB_HOST=$DB_HOST -> $GATEWAY_IP (Docker gateway for bridge mode)"
    DB_NAME=$(grep -E '^DB_DATABASE=' .env | cut -d '=' -f2)
    DB_USER=$(grep -E '^DB_USERNAME=' .env | cut -d '=' -f2)
    echo ""
    echo "MariaDB must accept connections from Docker (HTTP 500 fix):"
    echo "  1. sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf"
    echo "  2. sudo mysql -e \"GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'172.%.%.%'; FLUSH PRIVILEGES;\""
    echo "  3. sudo systemctl restart mariadb"
    echo ""
    DB_CHANGED=true
fi

sed -i "s|APP_PORT=.*|APP_PORT=$APP_PORT|" .env
sed -i "s|APP_SSL_PORT=.*|APP_SSL_PORT=$APP_SSL_PORT|" .env

if [ "$NO_RESTART" = true ]; then
    echo "Skipping container restart (--no-restart mode, caller will handle it)"
    exit 0
fi

echo ""
echo "Restarting containers..."
docker compose down 2>/dev/null || true
sleep 2
docker compose up -d

echo ""
echo "Application: http://localhost:${APP_PORT}  https://localhost:${APP_SSL_PORT}"
echo "Apache should proxy to these ports."
[ "$DB_CHANGED" = true ] && echo "" && echo "If you get HTTP 500: run the MariaDB commands above, then: docker compose restart app"
