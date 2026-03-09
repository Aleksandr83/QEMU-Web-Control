# Docker Host Network Mode for localhost DB Access

This configuration allows Docker containers to securely connect to a localhost database without exposing ports externally.

## Host Network Mode Advantages

✅ **Security:** DB remains on localhost (127.0.0.1)
✅ **Performance:** No NAT, direct connection
✅ **Simplicity:** `DB_HOST=localhost` works from container
✅ **Firewall:** No need to expose port 3306 externally

## Disadvantages

⚠️ **Isolation:** Containers see all host network interfaces
⚠️ **Ports:** Port conflicts (nginx on 80, 443 instead of 8080, 8443)
⚠️ **Compatibility:** Works only on Linux (not on Mac/Windows Docker Desktop)

## Option 1: Host Network Mode (recommended for production)

### docker/docker-compose.host-network.yml

```yaml
services:
  app:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_app
    restart: unless-stopped
    network_mode: "host"  # <-- Key change
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
      - ./docker/php/zz-docker.conf:/usr/local/etc/php-fpm.d/zz-docker.conf
    environment:
      - DB_HOST=localhost  # <-- Works!
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
    network_mode: "host"  # <-- Key change
    volumes:
      - ./:/var/www
      - ./docker/nginx/conf.d:/etc/nginx/conf.d
      - ./docker/nginx/ssl:/etc/nginx/ssl
    depends_on:
      - app

  scheduler:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_scheduler
    restart: unless-stopped
    network_mode: "host"  # <-- Key change
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    entrypoint: /bin/sh
    command: -c "while true; do php /var/www/artisan schedule:run --verbose --no-interaction; sleep 60; done"
```

### nginx configuration changes

When using host network mode, nginx listens on standard ports:

```nginx
# docker/nginx/conf.d/default.conf for host network
server {
    listen 80;  # Instead of 8080
    listen [::]:80;
    server_name _;
    
    root /var/www/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;  # localhost instead of app:9000
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

server {
    listen 443 ssl http2;  # Instead of 8443
    listen [::]:443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    
    root /var/www/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;  # localhost
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### .env configuration

```env
# Secure connection to localhost DB
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password

# Standard ports (host network mode)
APP_PORT=80
APP_SSL_PORT=443
```

### MariaDB configuration (secure)

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf

[mysqld]
# Listen ONLY on localhost - secure!
bind-address = 127.0.0.1

# Additional security
skip-name-resolve = 1
```

### Usage

```bash
# Switch to host network mode
cp docker/docker-compose.host-network.yml docker-compose.yml

# Update .env
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
sed -i 's/APP_PORT=.*/APP_PORT=80/' .env
sed -i 's/APP_SSL_PORT=.*/APP_SSL_PORT=443/' .env

# Restart
docker compose down
docker compose up -d

# Verify
docker compose exec app php artisan db:show
```

## Option 2: Unix Socket (maximum security)

### Unix Socket advantages

✅ **Most secure:** No network connection at all
✅ **Faster:** No TCP overhead
✅ **Simple firewall:** TCP port not used

### docker-compose.yml with socket

```yaml
services:
  app:
    # ... rest unchanged
    volumes:
      - ./:/var/www
      - /var/run/mysqld:/var/run/mysqld  # <-- Mount socket
    environment:
      - DB_HOST=/var/run/mysqld/mysqld.sock  # <-- Unix socket
```

### .env for Unix socket

```env
# Unix socket - most secure option
DB_CONNECTION=mysql
DB_HOST=/var/run/mysqld/mysqld.sock
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

### Using Unix socket

```bash
# Verify socket exists
ls -la /var/run/mysqld/mysqld.sock

# Update docker-compose.yml (add volume)
# Update .env
sed -i 's|DB_HOST=.*|DB_HOST=/var/run/mysqld/mysqld.sock|' .env

# Restart
docker compose down
docker compose up -d

# Verify
docker compose exec app php artisan db:show
```

## Option comparison

| Characteristic | Bridge (default) | Host Network | Unix Socket |
|----------------|------------------|--------------|-------------|
| DB security | ⚠️ External IP needed | ✅ localhost | ✅✅ No network |
| Isolation | ✅ Full | ⚠️ None | ✅ Full |
| Ports | 8080, 8443 | 80, 443 | 8080, 8443 |
| Performance | Good | Excellent | Best |
| Compatibility | All OS | Linux only | Linux |
| Complexity | Simple | Simple | Medium |

## Recommendations

### For Orange Pi (Production)

**Use Host Network Mode:**
```bash
cp docker/docker-compose.host-network.yml docker-compose.yml
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
```

**MariaDB configuration:**
```ini
bind-address = 127.0.0.1  # Secure!
```

**Firewall:**
```bash
# Port 3306 closed externally - not needed!
sudo ufw deny 3306/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### For development

**Unix Socket:**
```bash
# Add socket volume to docker-compose.yml
# Update .env with socket path
```

## Security

### Host Network Mode

```bash
# MariaDB listens only on localhost
ss -tlnp | grep 3306
# Should show: 127.0.0.1:3306

# External check (should fail)
mysql -h <orange_pi_ip> -u qemu_user -p
# ERROR 2002 (HY000): Can't connect to MySQL server

# Internal check (should work)
docker compose exec app mysql -h localhost -u qemu_user -p
# Connected!
```

### Unix Socket

```bash
# No network port at all!
ss -tlnp | grep 3306
# (empty)

# Only via socket
docker compose exec app mysql -h /var/run/mysqld/mysqld.sock -u qemu_user -p
# Connected!
```

## Migration from bridge to host network

```bash
# 1. Stop current configuration
docker compose down

# 2. Backup current compose
cp docker-compose.yml docker-compose.yml.bridge

# 3. Use host network
cp docker/docker-compose.host-network.yml docker-compose.yml

# 4. Update .env
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
sed -i 's/APP_PORT=.*/APP_PORT=80/' .env
sed -i 's/APP_SSL_PORT=.*/APP_SSL_PORT=443/' .env

# 5. Configure MariaDB for localhost only
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
# bind-address = 127.0.0.1

# 6. Restart
sudo systemctl restart mariadb
docker compose up -d

# 7. Verify
curl http://localhost
docker compose exec app php artisan db:show
```

## Troubleshooting

### Port conflict in host network mode

If nginx fails to start due to ports 80/443 in use:

```bash
# Check what uses the ports
sudo ss -tlnp | grep -E ':(80|443)'

# Stop conflicting service
sudo systemctl stop apache2  # or nginx

# Or change ports in nginx configuration
# listen 8080; instead of listen 80;
```

### Unix socket not found

```bash
# Check socket path
sudo grep socket /etc/mysql/mariadb.conf.d/50-server.cnf

# Usually:
# socket = /var/run/mysqld/mysqld.sock

# Directory permissions
sudo chmod 755 /var/run/mysqld
sudo chown mysql:mysql /var/run/mysqld/mysqld.sock
```

## Summary

**For maximum security on Orange Pi:**

1. ✅ Use **host network mode**
2. ✅ MariaDB with `bind-address = 127.0.0.1`
3. ✅ Firewall blocks port 3306
4. ✅ `DB_HOST=localhost` in `.env`
5. ✅ Application available on standard ports 80/443

**Result:** Database is fully protected, accessible only from localhost!

---

**Language versions:** [HOST-NETWORK-MODE.EN.md](HOST-NETWORK-MODE.EN.md) | [HOST-NETWORK-MODE.RU.md](../RU/HOST-NETWORK-MODE.RU.md)
