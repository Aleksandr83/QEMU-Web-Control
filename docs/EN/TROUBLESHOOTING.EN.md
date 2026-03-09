# Troubleshooting Guide

## Realistic Approach to Installation

In practice, especially on RISC-V, various issues may occur. This guide will help you resolve them.

## Post-Installation Checklist

### 1. Docker Check

```bash
# Check that Docker is running
sudo systemctl status docker

# If not running
sudo systemctl start docker
sudo systemctl enable docker

# Check version
docker --version
docker compose version
# or
docker-compose --version
```

### 2. Container Check

```bash
# View container status
docker compose ps
# or
docker-compose ps

# Should be running (Up):
# - qemu_app
# - qemu_nginx
# - qemu_db (if using Docker DB)
# - qemu_scheduler
```

**If containers are not running:**

```bash
# View logs
docker compose logs
# or specific container
docker compose logs app
docker compose logs nginx
docker compose logs db

# Try rebuilding
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 3. Database Check

```bash
# If using Docker DB
docker compose exec db mysql -u root -p

# If external DB
mysql -h localhost -u qemu_user -p qemu_control
```

**Verify database exists:**

```sql
SHOW DATABASES;
USE qemu_control;
SHOW TABLES;
```

**If database not created:**

```bash
# Create manually
sudo mysql -u root -p

CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
FLUSH PRIVILEGES;
EXIT;

# Run migrations
docker compose exec app php artisan migrate --seed
```

### 4. Permission Check

```bash
# Check file ownership
ls -la storage/
ls -la bootstrap/cache/
ls -la vendor/

# If permissions wrong
sudo chown -R 1000:1000 storage bootstrap/cache vendor node_modules
chmod -R 775 storage bootstrap/cache
```

### 5. Application Access Check

```bash
# Check that Nginx responds
curl http://localhost:8080

# If error, check logs
docker compose logs nginx
docker compose logs app
```

## Common Issues

### Issue 1: "Connection refused" when accessing site

**Cause:** Containers not running or ports in use

**Solution:**

```bash
# Check containers are running
docker compose ps

# Check if port is in use
sudo netstat -tlnp | grep 8080
sudo netstat -tlnp | grep 8443

# If port in use, change in .env
nano .env
# Change APP_PORT and APP_SSL_PORT

# Restart
docker compose down
docker compose up -d
```

### Issue 2: Database not created

**Cause:** Insufficient permissions or mysql client not installed

**Solution:**

```bash
# Use dedicated DB setup script
./scripts/setup-database.sh
```

This script will:
- Check MySQL connection
- Create user if needed
- Create database
- Grant privileges
- Verify everything works

**Manual creation:**

```bash
# Connect as root
sudo mysql -u root -p

# Create DB and user
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

# Verify
SHOW DATABASES LIKE 'qemu%';
EXIT;

# Run migrations
docker compose exec app php artisan migrate --seed
```

**Detailed diagnostics:** See [DATABASE-TROUBLESHOOTING.EN.md](DATABASE-TROUBLESHOOTING.EN.md)

**Or use Docker DB:**

```bash
nano .env
# Change DB_HOST=db

docker compose down
docker compose up -d
```

### Issue 3: Bridge errors when starting VM (bridge.conf, failed to drop privileges)

**Cause:** Bridge not configured or Docker restrictions with bridge networking

**Solution 1 — bridge.conf:**
```bash
./scripts/fix-qemu-bridge.sh
docker compose down && docker compose up -d
```

**Solution 2 — "failed to drop privileges":** QEMU runs on the host via QemuControlService; the container does not run QEMU. Ensure QemuControlService is installed and running on the host.

**Alternative:** Switch VM to "User (NAT)" network type in VM settings — no bridge required, works in any Docker mode.

### Issue 4: NPM errors on RISC-V

**Cause:** Node.js not installed or wrong version

**Solution:**

```bash
# Enter container
docker compose exec app bash

# Check Node.js
node --version
npm --version

# If not found, rebuild image
exit
docker compose down
docker compose build --no-cache app
docker compose up -d

# If error persists, install dependencies manually
docker compose exec app npm install --legacy-peer-deps
```

### Issue 5: Slow build on RISC-V

**Cause:** This is normal for RISC-V 😊

**Solution:**

```bash
# Be patient ☕
# PHP image build: 15-25 minutes
# NPM install: 5-10 minutes
# NPM build: 2-4 minutes

# Monitor progress
docker compose logs -f app
```

### Issue 6: Apache2 not working as proxy

**Cause:** Modules not enabled or wrong configuration

**Solution:**

```bash
# Enable modules
sudo a2enmod proxy
sudo a2enmod proxy_http

# Verify configuration
sudo apache2ctl configtest

# If error, check file
sudo nano /etc/apache2/sites-available/qemu-control.conf

# Enable site
sudo a2ensite qemu-control.conf

# Restart Apache2
sudo systemctl restart apache2

# Check logs
sudo tail -f /var/log/apache2/error.log
```

### Issue 7: "502 Bad Gateway" through Apache2

**Cause:** Docker container not running or wrong port

**Solution:**

```bash
# Check Docker
docker compose ps

# Check application responds
curl http://localhost:8080

# Check port in Apache config
sudo nano /etc/apache2/sites-available/qemu-control.conf
# Ensure: ProxyPass / http://localhost:8080/

# Restart Apache2
sudo systemctl restart apache2
```

### Issue 8: Migrations not running

**Cause:** Database unavailable or wrong credentials

**Solution:**

```bash
# Check connection
docker compose exec app php artisan db:show

# If error, check .env
cat .env | grep DB_

# Verify DB is accessible
docker compose exec app php artisan tinker
>>> DB::connection()->getPdo();

# Run migrations manually
docker compose exec app php artisan migrate --force
docker compose exec app php artisan db:seed --force
```

### Issue 9: "SQLSTATE[HY000] [2002] Connection refused" error

**Cause:** Database not running or wrong host

**Solution:**

```bash
# If using Docker DB
docker compose ps db
# If not running
docker compose up -d db

# If using external DB
sudo systemctl status mariadb
# If not running
sudo systemctl start mariadb

# Check DB_HOST in .env
cat .env | grep DB_HOST
# For Docker DB should be: DB_HOST=db
# For external DB: DB_HOST=localhost or IP
```

### Issue 10: Preview returns 404 / "No signal"

**Cause:** QMP socket not found; VM not running; or wrong permissions on `/var/qemu/qmp`

**Solution:**

```bash
# 1. Check QemuControlService logs (on host)
sudo tail -f /var/log/QemuControlService.log

# 2. Fix /var/qemu/qmp permissions (QEMU runs as root)
sudo chown root:root /var/qemu/qmp
sudo chmod 755 /var/qemu/qmp

# 3. Ensure VM is running, then check socket exists
ls -la /var/qemu/qmp/

# 4. Docker: ensure QEMU_CONTROL_SERVICE_URL reaches host (run fix script)
sudo ./scripts/fix-boot-media-docker.sh
docker compose restart app
```

### Issue 11: White screen or 500 error

**Cause:** Code error or wrong permissions

**Solution:**

```bash
# Check Laravel logs
docker compose exec app tail -f storage/logs/laravel.log

# Clear cache
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear

# Check permissions
sudo chown -R 1000:1000 storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Regenerate application key
docker compose exec app php artisan key:generate --force
```

### Issue 12: "Connection lost" when accessing VNC from another computer

**Cause:** WebSocket connects but websockify (on host) cannot reach QEMU VNC, or firewall blocks port 50055.

**Solution:**

```bash
# 1. Check VM is running and VNC is enabled
docker compose exec app php artisan tinker
>>> \App\Models\VirtualMachine::find(1)->only(['status','vnc_port']);
# status should be running, vnc_port — 5900 or higher

# 2. Check websockify is listening on host (port 50055)
ss -tlnp | grep 50055
# QemuControlService starts websockify when VNC_TOKEN_FILE is set in qemu-control.conf

# 3. Check VM VNC port on host
ss -tlnp | grep 5900

# 4. Check firewall (app ports and 50055)
sudo ufw status
sudo ufw allow 50055/tcp
sudo ufw reload

# 5. VNC_WS_HOST in .env — host:50055 reachable from clients
grep VNC_WS_HOST .env
# From host: VNC_WS_HOST=127.0.0.1:50055
# From VM: VNC_WS_HOST=10.0.2.15:50055
# From LAN: VNC_WS_HOST=192.168.1.41:50055

# 6. Restart QemuControlService (restarts websockify)
sudo systemctl restart QemuControlService

# 7. Log when opening console (ws_url)
docker compose exec app tail -100 storage/logs/laravel.log | grep "VNC console opened"

# 8. QemuControlService logs (including websockify)
sudo tail -50 /var/log/QemuControlService.log
# Or: ./scripts/show_logs.sh qemu-control
```

**When accessing from RISC-V client:** Ensure browser supports WebSocket. Try from another device on the same network — if it works there, the RISC-V browser may be the issue.

**When accessing from another computer:** Set `VNC_WS_HOST` in `.env` — host:50055 reachable from client. Fallback: request host is used (APP_URL).

### Issue 12a: "Connection lost" when accessing VNC over HTTPS

**Cause:** When using HTTPS with a self-signed certificate, the browser may reject the WebSocket connection if the certificate does not match the host (e.g., issued for localhost but accessed via IP).

**Solution:**

1. **Accept the certificate before opening console:** Open the main application page over HTTPS (e.g., `https://10.0.2.15:8080`), click "Advanced" → "Proceed to site" (or similar in your browser). Only then open the VM console.

2. **Certificate for IP:** When accessing by IP (10.0.2.15 etc.), create a certificate with SAN for that IP:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout docker/nginx/ssl/server.key -out docker/nginx/ssl/server.crt \
     -subj "/CN=10.0.2.15" -addext "subjectAltName=IP:10.0.2.15"
   docker compose restart nginx
   ```

3. **Let's Encrypt:** When accessing by domain, use Let's Encrypt certificate (see setup documentation).

### Issue 13: Composer errors

**Cause:** Insufficient memory or dependency issues

**Solution:**

```bash
# Increase memory limit for Composer
docker compose exec app php -d memory_limit=-1 /usr/bin/composer install

# Or clear Composer cache
docker compose exec app composer clear-cache
docker compose exec app composer install --no-cache
```

### Issue 14: QEMU exits immediately — PipeWire "can't load config client.conf"

**Cause:** QEMU tries to use PipeWire for audio on a headless server where PipeWire is not installed or configured.

**Solution:**

By default, QEMU audio is disabled (`QEMU_DISABLE_AUDIO=true` in config). If you see this error:

```bash
# 1. Ensure audio is disabled (default)
grep QEMU_DISABLE_AUDIO .env || echo "QEMU_DISABLE_AUDIO=true" >> .env

# 2. Rebuild and restart
docker compose down && docker compose up -d

# 3. If error persists, install PipeWire (alternative)
sudo apt install pipewire pipewire-pulse
# Or create minimal config: sudo mkdir -p /etc/pipewire && echo '{}' | sudo tee /etc/pipewire/client.conf
```

**Note:** QEMU 8.2+ uses `-audio none` to disable audio. On older QEMU, set `QEMU_DISABLE_AUDIO=false` and install PipeWire.

### Issue 15: "Failed to get write lock" — disk image in use

**Cause:** Another QEMU process or zombie process is using the disk image.

**Solution:**

```bash
# 1. Find processes using the disk (check QEMU_VM_STORAGE in .env for your path)
VM_UUID="b47d58b5-232f-438e-87c1-7480c00a72c4"
DISK_PATH="/var/lib/qemu/vms/${VM_UUID}/disk.qcow2"

sudo lsof "$DISK_PATH"
# or
sudo fuser -v "$DISK_PATH"

# 2. Kill stale QEMU processes for this VM
ps aux | grep qemu | grep "$VM_UUID"
sudo kill -9 <PID>

# 3. If VM is in "running" but process is dead, reset status in app
docker compose exec app php artisan tinker
>>> $vm = \App\Models\VirtualMachine::where('uuid', 'b47d58b5-232f-438e-87c1-7480c00a72c4')->first();
>>> $vm->update(['status' => 'stopped', 'pid' => null]);

# 4. Remove stale lock (only if no process uses the disk)
sudo qemu-img check "$DISK_PATH"
# If "No errors found", try starting VM again
```

## Diagnostics

### Full System Diagnostics

```bash
#!/bin/bash
echo "=== System Info ==="
uname -a
echo ""

echo "=== Docker Version ==="
docker --version
docker compose version 2>/dev/null || docker-compose --version
echo ""

echo "=== Docker Status ==="
sudo systemctl status docker --no-pager
echo ""

echo "=== Containers Status ==="
docker compose ps
echo ""

echo "=== Container Logs (last 20 lines) ==="
docker compose logs --tail=20
echo ""

echo "=== Disk Space ==="
df -h
echo ""

echo "=== Memory Usage ==="
free -h
echo ""

echo "=== Network Ports ==="
sudo netstat -tlnp | grep -E ':(80|443|8080|8443|3306)'
echo ""

echo "=== Database Connection ==="
docker compose exec -T app php artisan db:show 2>&1 || echo "Database connection failed"
echo ""

echo "=== File Permissions ==="
ls -la storage/ | head -10
ls -la bootstrap/cache/ | head -10
echo ""

echo "=== Environment ==="
cat .env | grep -E '^(APP_|DB_)' | grep -v PASSWORD
echo ""
```

Run diagnostics script:

```bash
chmod +x scripts/diagnose.sh
./scripts/diagnose.sh > diagnosis.txt
cat diagnosis.txt
```

## When Nothing Helps

### Full Reinstall

```bash
# 1. Stop and remove everything
./uninstall.sh --clean --lang ru

# 2. Clean Docker
docker system prune -a --volumes
docker volume prune

# 3. Remove database (if external)
sudo mysql -u root -p
DROP DATABASE IF EXISTS qemu_control;
EXIT;

# 4. Start fresh
./install.sh --lang ru
```

## Getting Help

If the issue persists:

1. **Collect diagnostics:**
```bash
./scripts/diagnose.sh > diagnosis.txt
```

2. **Collect logs:**
```bash
docker compose logs > docker-logs.txt
sudo tail -100 /var/log/apache2/error.log > apache-logs.txt
```

3. **Describe the problem:**
   - What you were trying to do
   - What happened
   - Error messages
   - Your system (Orange Pi RV2, Ubuntu, etc.)

4. **Attach files:**
   - diagnosis.txt
   - docker-logs.txt
   - Error screenshots

## Known Limitations

### On RISC-V (Orange Pi RV2):

- ⚠️ Image build: 20-30 minutes (patience!)
- ⚠️ NPM may be unstable (use `--legacy-peer-deps`)
- ⚠️ MariaDB may run slower (consider external DB)
- ⚠️ Some packages may not have prebuilt binaries

### General:

- ⚠️ VNC requires additional setup
- ⚠️ x86 VM emulation on RISC-V is slow
- ⚠️ First run may take 5-10 minutes

## Tips for Stable Operation

1. **Use external DB** on RISC-V (faster and more stable)
2. **Increase swap** if RAM < 4GB
3. **Regularly clean** Docker cache: `docker system prune`
4. **Monitor resources**: `htop`, `docker stats`
5. **Back up** database regularly
6. **Check logs** when behavior is strange
7. **Update system**: `sudo apt update && sudo apt upgrade`

## Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Laravel Documentation](https://laravel.com/docs)
- [MariaDB Documentation](https://mariadb.org/documentation/)
- [Apache2 Documentation](https://httpd.apache.org/docs/)
- [QEMU Documentation](https://www.qemu.org/documentation/)

---

**Remember:** Installing on RISC-V is an adventure! Not everything will go smoothly the first time, and that's okay. 😊
