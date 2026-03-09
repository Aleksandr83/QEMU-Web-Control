# QEMU Web Control Command Reference

## Management Scripts

### install.sh - Application Installation

```bash
# Installation with auto language detection
./install.sh

# Installation in Russian
./install.sh --lang ru

# Installation in English
./install.sh --lang en
```

**What it does:**
- Checks and installs Docker
- Configures .env file
- Choose Docker or external DB
- Generates SSL certificates
- Builds Docker containers
- Installs dependencies (Composer, NPM)
- Runs migrations and seeders
- Fixes permissions

---

### start.sh - Start Application

```bash
# Start
./start.sh

# Start with Russian language
./start.sh --lang ru
```

**What it does:**
- Starts all Docker containers
- Shows access URL

---

### stop.sh - Stop Application

```bash
# Stop
./stop.sh

# Stop with Russian language
./stop.sh --lang ru
```

**What it does:**
- Stops all Docker containers
- Saves data to DB

---

### restart.sh - Restart Application

```bash
# Restart
./restart.sh

# Restart with Russian language
./restart.sh --lang ru
```

**What it does:**
- Restarts all Docker containers
- Shows access URL

---

### uninstall.sh - Uninstall Application

```bash
# Uninstall (keeps project files)
./uninstall.sh

# Full removal
./uninstall.sh --clean

# With Russian language
./uninstall.sh --clean --lang ru
```

**Options:**
- `--clean` - also removes project files
- `--lang` - message language (en/ru)

**What it does:**
- Stops containers
- Removes containers
- Removes volumes
- Removes images
- Optionally removes project files

---

### setup-database.sh - Database Setup

```bash
# Run
./scripts/setup-database.sh
```

**What it does:**
1. Reads configuration from `.env`
2. Checks MySQL connection
3. Checks/creates user
4. Checks/creates database
5. Grants privileges
6. Verifies user access to DB
7. Lists all databases

**Usage:**
- On first install, if `install.sh` did not create the DB
- After changing DB parameters in `.env`
- For DB reinstall
- For DB troubleshooting

**See also:** [DATABASE-TROUBLESHOOTING.EN.md](DATABASE-TROUBLESHOOTING.EN.md)

---

### fix-database-riscv.sh - MariaDB Fix for RISC-V

```bash
# Run (RISC-V only)
./scripts/fix-database-riscv.sh
```

**Interactive menu:**
1. Install MariaDB on host system (recommended)
2. Use docker-compose without DB container
3. Use PostgreSQL (experimental)
4. Use SQLite (lightweight option)

**When to use:**
- Error `no matching manifest for linux/riscv64` for MariaDB
- `db` container fails to start on RISC-V
- Need to quickly run project without Docker DB

**Automatic actions:**
- Creates docker-compose.yml backup
- Installs DB on host (option 1)
- Switches to docker/docker-compose.riscv.yml
- Updates .env for host DB connection
- Runs setup-database.sh to create DB

**See also:** [RISCV.EN.md](RISCV.EN.md) section "MariaDB does not start"

---

### fix-nodejs-riscv.sh - Node.js Fix for RISC-V

```bash
# Run (RISC-V only)
./scripts/fix-nodejs-riscv.sh
```

**Interactive menu:**
1. Use simplified Dockerfile (recommended - fast)
2. Install Node.js on host system (for development)
3. Try to fix current Dockerfile (experimental)
4. Skip Node.js installation (API mode only)

**When to use:**
- Error `ERROR 404: Not Found` when installing Node.js
- Problems with unofficial-builds.nodejs.org
- Long Docker image build with Node.js
- Need to quickly run project on RISC-V

**Automatic actions:**
- Creates current Dockerfile backup
- Rebuilds Docker images
- Verifies Node.js installation success
- Restores backup on failure

**See also:** [RISCV.EN.md](RISCV.EN.md) section "Node.js does not install"

---

### scripts/autostart-service.sh - Autostart Management

```bash
# Install autostart service
./scripts/autostart-service.sh --install --lang ru

# Check status
./scripts/autostart-service.sh --status --lang ru

# Remove service
./scripts/autostart-service.sh --uninstall --lang ru
```

**Commands:**
- `--install` - install systemd service
- `--uninstall` - remove service
- `--status` - show service status
- `--help` - help

---

## Artisan Commands

### vm:autostart - VM Autostart

```bash
# Start all VMs with autostart
docker compose exec app php artisan vm:autostart
```

**What it does:**
- Finds all VMs with `autostart = true`
- Starts stopped VMs
- Shows startup statistics

---

### key:generate - Generate Key

```bash
docker compose exec app php artisan key:generate
```

---

### migrate - Run Migrations

```bash
# Apply migrations
docker compose exec app php artisan migrate

# Rollback last migration
docker compose exec app php artisan migrate:rollback

# Reset and reapply
docker compose exec app php artisan migrate:fresh

# With seeders
docker compose exec app php artisan migrate:fresh --seed
```

---

### db:seed - Seed Database

```bash
# Run all seeders
docker compose exec app php artisan db:seed

# Run specific seeder
docker compose exec app php artisan db:seed --class=DatabaseSeeder
```

---

### storage:link - Symbolic Link

```bash
docker compose exec app php artisan storage:link
```

---

### cache:clear - Clear Cache

```bash
# Clear application cache
docker compose exec app php artisan cache:clear

# Clear config cache
docker compose exec app php artisan config:clear

# Clear route cache
docker compose exec app php artisan route:clear

# Clear view cache
docker compose exec app php artisan view:clear

# Clear all
docker compose exec app php artisan optimize:clear
```

---

### tinker - Interactive Console

```bash
docker compose exec app php artisan tinker
```

**Usage examples:**

```php
// List all users
User::all();

// Find VMs with autostart
VirtualMachine::where('autostart', true)->get();

// Create new user
User::create([
    'name' => 'Test User',
    'email' => 'test@example.com',
    'password' => Hash::make('password')
]);
```

---

## Docker Compose Commands

### Basic Commands

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose stop

# Restart containers
docker compose restart

# Stop and remove containers
docker compose down

# View logs
docker compose logs

# Follow logs
docker compose logs -f

# Logs for specific service
docker compose logs app
docker compose logs nginx
docker compose logs db
```

---

### Running Commands in Containers

```bash
# Enter app container bash
docker compose exec app bash

# Run command in container
docker compose exec app [command]

# Run command without TTY (for scripts)
docker compose exec -T app [command]
```

---

### Container Management

```bash
# Rebuild containers
docker compose build

# Rebuild without cache
docker compose build --no-cache

# Start specific service
docker compose up -d app

# View container status
docker compose ps

# View resource usage
docker compose stats
```

---

## NPM Commands

### Development

```bash
# Install dependencies
docker compose exec app npm install

# Run dev server
docker compose exec app npm run dev

# Build for production
docker compose exec app npm run build
```

---

## Composer Commands

```bash
# Install dependencies
docker compose exec app composer install

# Update dependencies
docker compose exec app composer update

# Add package
docker compose exec app composer require vendor/package

# Remove package
docker compose exec app composer remove vendor/package

# List installed packages
docker compose exec app composer show
```

---

## Database Operations

### Connect to MariaDB

```bash
# Enter DB console
docker compose exec db mysql -u root -p

# Connect as application user
docker compose exec db mysql -u qemu_user -p qemu_control
```

### Export Database

```bash
# Export entire DB
docker compose exec db mysqldump -u root -p qemu_control > backup.sql

# Export with compression
docker compose exec db mysqldump -u root -p qemu_control | gzip > backup.sql.gz
```

### Import Database

```bash
# Import from file
docker compose exec -T db mysql -u root -p qemu_control < backup.sql

# Import from archive
gunzip < backup.sql.gz | docker compose exec -T db mysql -u root -p qemu_control
```

---

## System Commands

### Permissions

```bash
# Fix permissions (from install.sh)
sudo chown -R 1000:1000 vendor node_modules storage bootstrap/cache public
chmod -R 775 storage bootstrap/cache
```

### SSL Certificates

```bash
# Generate new certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout docker/nginx/ssl/server.key \
    -out docker/nginx/ssl/server.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=QEMU/CN=localhost"

# Verify certificate
openssl x509 -in docker/nginx/ssl/server.crt -text -noout
```

### Logs

```bash
# Laravel logs
tail -f storage/logs/laravel.log

# Nginx logs
docker compose logs -f nginx

# PHP-FPM logs
docker compose logs -f app

# MariaDB logs
docker compose logs -f db

# All logs
docker compose logs -f
```

---

## Useful Commands

### System Check

```bash
# Check PHP version
docker compose exec app php -v

# Check Laravel version
docker compose exec app php artisan --version

# Check DB connection
docker compose exec app php artisan tinker
>>> DB::connection()->getPdo();

# Check migration status
docker compose exec app php artisan migrate:status
```

### System Cleanup

```bash
# Remove unused Docker images
docker system prune -a

# Remove volumes
docker volume prune

# Clear Laravel caches
docker compose exec app php artisan optimize:clear
```

### Diagnostics

```bash
# Check Laravel configuration
docker compose exec app php artisan config:show

# Check routes
docker compose exec app php artisan route:list

# Check task scheduler
docker compose exec app php artisan schedule:list

# Application info
docker compose exec app php artisan about
```

---

## Quick Commands (aliases)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Aliases for QEMU Web Control
alias qemu-start='cd /path/to/QemuWebControl && ./start.sh'
alias qemu-stop='cd /path/to/QemuWebControl && ./stop.sh'
alias qemu-restart='cd /path/to/QemuWebControl && ./restart.sh'
alias qemu-logs='cd /path/to/QemuWebControl && docker compose logs -f'
alias qemu-shell='cd /path/to/QemuWebControl && docker compose exec app bash'
alias qemu-tinker='cd /path/to/QemuWebControl && docker compose exec app php artisan tinker'
alias qemu-migrate='cd /path/to/QemuWebControl && docker compose exec app php artisan migrate'
```

After adding:

```bash
source ~/.bashrc
```

---

## Let's Encrypt Auto-Renewal

After importing a Let's Encrypt certificate via Settings > Certificates, add to crontab for auto-renewal:

```bash
crontab -e
# Add (replace path with your project):
0 3 * * * certbot renew --quiet --deploy-hook "/path/to/QemuWebControl/scripts/renew-letsencrypt-deploy-hook.sh"
```

The deploy hook copies renewed certs to nginx and reloads it. Requires certbot on the host:

```bash
sudo apt install certbot
```

Manual copy after certbot renew:

```bash
docker compose exec app php artisan certificates:renew
docker compose exec nginx nginx -s reload
```

---

## Troubleshooting Commands

### Containers Not Starting

```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker -n 100
```

### Database Errors

```bash
# Check DB availability
docker compose exec app php artisan db:show

# Recreate DB
docker compose exec app php artisan migrate:fresh --seed
```

### Permission Issues

```bash
# Check file ownership
ls -la storage/
ls -la vendor/

# Fix permissions
sudo chown -R 1000:1000 storage bootstrap/cache vendor node_modules
chmod -R 775 storage bootstrap/cache
```

### Cleanup and Restart

```bash
# Full cleanup and restart
docker compose down -v
docker compose build --no-cache
./install.sh
```

---

## Documentation

- [README.md](README.md) - Main documentation (EN)
- [README.RU.md](../../README.RU.md) - Main documentation (RU)
- [INSTALL.EN.md](INSTALL.EN.md) / [INSTALL.RU.md](../RU/INSTALL.RU.md) - Quick installation
- [AUTOSTART.EN.md](AUTOSTART.EN.md) / [AUTOSTART.RU.md](../RU/AUTOSTART.RU.md) - Autostart guide (EN/RU)
- [COMMANDS.EN.md](COMMANDS.EN.md) - This file (EN)
- [COMMANDS.RU.md](../RU/COMMANDS.RU.md) - Command reference (RU)
- [CHANGELOG.EN.md](CHANGELOG.EN.md) / [CHANGELOG.RU.md](../RU/CHANGELOG.RU.md) - Changelog (EN/RU)
- [TROUBLESHOOTING.EN.md](TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](../RU/TROUBLESHOOTING.RU.md) - Troubleshooting (EN/RU)

---

**Tip:** Bookmark this file for quick access to commands!
