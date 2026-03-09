# RISC-V Quick Start

## Orange Pi RV2 / VisionFive / Milk-V

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git curl wget

# Increase swap (if RAM < 4GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Step 2: Docker Installation

On Orange Pi RV2 Docker is installed as `docker.io`:

```bash
# Update system
sudo apt-get update

# Install Docker and Docker Compose
sudo apt-get install -y docker.io docker-compose

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker-compose --version

# Re-login
exit
# Log in again via SSH
```

**Note**: The `install.sh` script can install Docker automatically if it's missing.

### Step 3: Clone Project

```bash
cd /var/www
sudo mkdir -p QemuWebControl
sudo chown -R $USER:$USER QemuWebControl
cd QemuWebControl

# Copy project files here
```

### Step 4: Installation

```bash
# Run installation
chmod +x install.sh
./install.sh --lang ru
```

**Important**: Installation will take 20-30 minutes! This is normal for RISC-V.

### Step 5: Verification

```bash
# Check container status
docker compose ps

# Should be running:
# - qemu_app
# - qemu_nginx
# - qemu_db
# - qemu_scheduler
```

### Step 6: Access

Open in browser:
- HTTP: http://your-orange-pi-ip:8080
- HTTPS: https://your-orange-pi-ip:8443

Login: admin  
Password: admin

## If Something Goes Wrong

### Full Problem Diagnostics

**Run diagnostics script:**

```bash
./scripts/full-diagnostic.sh
```

The script creates a detailed report `diagnostic-YYYYMMDD-HHMMSS.log` with:
- System information
- Docker configuration
- Container status
- All service logs
- DB check
- Problem analysis
- Fix recommendations

**Send the log to the developer or use for self-diagnostics.**

### Node.js Not Installing (ERROR 404)

**Quick fix:**

```bash
# Run automatic fix script
./scripts/fix-nodejs-riscv.sh

# Choose option:
# 1 - Simplified Dockerfile (recommended)
# 2 - Install Node.js on host
# 3 - Try to fix current Dockerfile
# 4 - Skip Node.js (API only)
```

**Manual fix:**

```bash
# Option 1: Simplified Dockerfile
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile
docker compose down
docker compose build --no-cache app
docker compose up -d

# Option 2: Node.js on host
sudo apt-get install -y nodejs npm
npm install
npm run build
```

### MariaDB Not Starting Even with External DB Selected

**Problem:** 
```
no matching manifest for linux/riscv64
```

**Quick fix:**

```bash
# Automatic fix
./scripts/quick-fix-riscv.sh

# Script will do everything automatically
```

**Or use:**

```bash
# Fix DB configuration
./scripts/fix-database-riscv.sh
# Choose option 1 or 2
```

### MariaDB Not Starting

**Cause:** No MariaDB image for RISC-V

**Quick fix:**

```bash
# Use automatic fix script
./scripts/fix-database-riscv.sh

# Recommended: choose option 1:
# Install MariaDB on host system
```

**Manual fix:**

```bash
# Stop containers
docker compose down

# Install MariaDB on host
sudo apt install -y mariadb-server

# Configure MariaDB
sudo mysql_secure_installation

# Create DB and user
sudo mysql -u root -p
```

In MySQL console:
```sql
CREATE DATABASE qemu_control;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Edit `.env`:
```bash
nano .env
```

Change:
```env
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

Restart:
```bash
./start.sh --lang ru
```

### NPM Errors

If NPM doesn't work:

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
```

### Slow Performance

Optimization:

```bash
# Stop unnecessary services
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth

# Clear cache
sudo apt clean
docker system prune -a

# Reboot
sudo reboot
```

## Recommended VM Settings for RISC-V

When creating virtual machines:

- **CPU**: 1 core (max 2)
- **RAM**: 512 MB (max 1024 MB)
- **Disk**: 10 GB (max 20 GB)
- **Network**: User (NAT)
- **VNC**: Don't use (slow)

## Monitoring

```bash
# Resource usage
htop

# Docker status
docker stats

# Application logs
docker compose logs -f app
```

## Useful Commands

```bash
# Restart
./restart.sh --lang ru

# Stop
./stop.sh --lang ru

# Logs
docker compose logs -f

# Enter container
docker compose exec app bash

# DB check
docker compose exec app php artisan db:show
```

## Performance

Expected execution time on Orange Pi RV2:

| Operation | Time |
|-----------|------|
| Image build | 15-25 min |
| Composer install | 3-5 min |
| NPM install | 5-10 min |
| NPM build | 2-4 min |
| VM start | 5-15 sec |
| Page load | 1-3 sec |

## Support

Detailed documentation: [RISCV.EN.md](RISCV.EN.md) / [RISCV.RU.md](../RU/RISCV.RU.md)

General documentation: [README.RU.md](../../README.RU.md)

---

**Language versions:** [RISCV-QUICKSTART.EN.md](RISCV-QUICKSTART.EN.md) | [RISCV-QUICKSTART.RU.md](../RU/RISCV-QUICKSTART.RU.md)
