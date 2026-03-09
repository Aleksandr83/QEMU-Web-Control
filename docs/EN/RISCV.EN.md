# Installation on RISC-V Architecture

## RISC-V Installation Features (Orange Pi, VisionFive, etc.)

The project is adapted for RISC-V architecture with some specifics.

## Requirements

- Linux RISC-V (tested on Orange Pi RV2)
- Docker with RISC-V support
- QEMU for RISC-V (if planning to run VMs)

## Docker Installation on RISC-V

On RISC-V systems (Orange Pi RV2, VisionFive, etc.) Docker is installed from the repository as `docker.io`:

```bash
# Update system
sudo apt-get update

# Install Docker and Docker Compose
sudo apt-get install -y docker.io docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Re-login to apply changes
exit
# Log in again
```

**Note**: The `install.sh` script automatically detects RISC-V and uses the correct installation method.

## Docker Image Specifics

### MariaDB
On RISC-V the latest MariaDB is used with explicit platform:
```yaml
db:
  image: mariadb:latest
  platform: linux/riscv64
```

### Nginx
Nginx is built from Alpine image which supports RISC-V:
```yaml
nginx:
  build:
    context: ./docker/nginx
    dockerfile: Dockerfile
```

### PHP-FPM
PHP 8.3-FPM with automatic Node.js installation for RISC-V:
- Node.js installed from multiple sources with fallback
- Priority: NodeSource → unofficial-builds → Debian → build from source
- Version: 20.x LTS (latest available for RISC-V)

#### Node.js Issue on RISC-V

Some Node.js versions may be unavailable for RISC-V. The Dockerfile uses several fallbacks:

1. **NodeSource repository** (most reliable)
2. **Unofficial builds** v20.18.1, v20.11.1
3. **Debian repositories** (stable but old version)
4. **Build from source** (slow but reliable)

If problems persist, use the simplified version:

```bash
# Copy simplified Dockerfile
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile

# Rebuild image
docker compose build --no-cache app
```

**Alternative:** Run Vite on host instead of Docker:

```bash
# Install Node.js on host
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# Run application without Vite in Docker
docker compose up -d

# Install dependencies on host and run Vite
npm install
npm run dev
```

## Installation

```bash
# Standard installation
./install.sh --lang ru
```

Installation may take longer on RISC-V due to:
- Image building (especially PHP with Node.js)
- Slower architecture compared to x86_64

## Possible Issues

### 1. Docker Not Installing via get.docker.com

**Problem:**
```
Package 'docker-ce' has no installation candidate
```

**Solution:**
On RISC-V use `docker.io` from repository:
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

The `install.sh` script automatically detects RISC-V and uses the correct method.

### 3. Node.js Not Installing

**Problem:**
```
ERROR 404: Not Found
# or
wget: unable to resolve host address 'unofficial-builds.nodejs.org'
```

**Cause:**
Node.js files for RISC-V may be unavailable or repository unreachable.

**Solution 1: Use Simplified Dockerfile**

```bash
# Stop containers
docker compose down

# Use simplified version
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile

# Rebuild
docker compose build --no-cache app
docker compose up -d
```

**Solution 2: Install Node.js on Host**

```bash
# Install Node.js on host
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# Verify version
node --version
npm --version

# Modify docker-compose.yml, remove npm commands
# Start application
docker compose up -d

# Install dependencies on host
npm install
npm run build

# For development run Vite on host
npm run dev
```

**Solution 3: Build Node.js from Source (long, ~30-60 minutes)**

```bash
# On host or in container
wget https://nodejs.org/dist/v20.11.1/node-v20.11.1.tar.gz
tar -xf node-v20.11.1.tar.gz
cd node-v20.11.1
./configure
make -j$(nproc)
sudo make install
```

### 4. "no matching manifest" Error

**Problem:**
```
no matching manifest for linux/riscv64 in the manifest list entries
```

**Solution:**
Ensure you use an updated docker-compose.yml with RISC-V support.

Check that in docker-compose.yml:
- Nginx is built from Dockerfile
- MariaDB uses `platform: linux/riscv64`
- PHP is built with manual Node.js installation

### 5. docker-compose: command not found

**Problem:**
```
docker-compose: command not found
```

**Solution:**
Install docker-compose:
```bash
sudo apt-get install -y docker-compose
```

Or use built-in Docker command:
```bash
# Instead of docker-compose use:
docker compose up -d
docker compose down
docker compose logs
```

### 6. Slow Image Build

**Problem:** PHP image build takes 10-20 minutes

**Solution:** This is normal for RISC-V. Wait for build to complete.

### 7. Node.js Not Found

**Problem:**
```
npm: command not found
```

**Solution:**
Verify Node.js is installed in container:
```bash
docker compose exec app node --version
docker compose exec app npm --version
```

If not installed, use solutions from "3. Node.js Not Installing" above.

### 8. MariaDB Not Starting Even with External DB Selected

**Problem:** Chose external DB during install but still get:
```
no matching manifest for linux/riscv64 in the manifest list entries
```

**Cause:** In older versions `install.sh` did not switch `docker-compose.yml` to version without DB container for RISC-V.

**Quick fix:**

```bash
# Automatic fix for current installation
./scripts/quick-fix-riscv.sh
```

The script automatically:
- Checks DB configuration
- Switches to docker/docker-compose.riscv.yml
- Restarts containers
- Verifies DB connection
- Runs migrations if needed

**Manual fix:**

```bash
# 1. Stop containers
docker compose down

# 2. Switch docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
cp docker/docker-compose.riscv.yml docker-compose.yml

# 3. Check .env
nano .env
# Ensure DB_HOST=localhost (not db)

# 4. Create DB if not created
./scripts/setup-database.sh

# 5. Start containers
docker compose up -d

# 6. Run migrations
docker compose exec app php artisan migrate --seed
```

### 9. MariaDB Container Keeps Trying to Start

**Problem:** db container constantly restarts

**Cause:** MariaDB has no official image for RISC-V

**Quick fix:**

```bash
# Automatic fix
./scripts/fix-database-riscv.sh

# Choose option:
# 1 - Install MariaDB on host (recommended)
# 2 - Use docker-compose without DB
# 3 - Use PostgreSQL
# 4 - Use SQLite (lightweight option)
```

**Manual fix (MariaDB on host):**

```bash
# Install MariaDB on host
sudo apt-get update
sudo apt-get install -y mariadb-server mariadb-client

# Start MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Change docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
cp docker/docker-compose.riscv.yml docker-compose.yml

# Update .env
nano .env
# Change: DB_HOST=localhost

# Create DB
./scripts/setup-database.sh

# Start containers
docker compose up -d
```

## Performance

### Expected Performance on Orange Pi RV2:

- **Image build**: 15-25 minutes
- **Container start**: 30-60 seconds
- **Composer install**: 3-5 minutes
- **NPM install**: 5-10 minutes
- **NPM build**: 2-4 minutes

### Optimization:

1. **Use external DB** instead of Docker container
2. **Increase swap** if low RAM:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

3. **Disable unnecessary services** to free resources

## QEMU on RISC-V

### QEMU Installation

```bash
sudo apt-get install qemu-system-x86 qemu-system-arm qemu-utils
```

### Specifics:

- QEMU on RISC-V works via emulation
- VM performance will be lower than on x86_64
- Recommended for lightweight VMs

### Recommended VM Settings:

- **CPU**: 1-2 cores (more doesn't help)
- **RAM**: 512-1024 MB
- **Disk**: 10-20 GB
- **Network**: user (NAT)

## Alternative Options

### Option 1: External DB

```bash
# Install MariaDB on host
sudo apt-get install mariadb-server

# Configure access
sudo mysql_secure_installation

# During install choose External DB
./install.sh --lang ru
```

### Option 2: SQLite (Lightweight)

If MariaDB is slow, use SQLite:

1. Change `.env`:
```env
DB_CONNECTION=sqlite
DB_DATABASE=/var/www/database/database.sqlite
```

2. Create DB file:
```bash
touch database/database.sqlite
chmod 664 database/database.sqlite
```

3. Run migrations:
```bash
docker compose exec app php artisan migrate --seed
```

## Resource Monitoring

```bash
# Container resource usage
docker stats

# System resource usage
htop

# Disk usage
df -h
```

## RISC-V Recommendations

1. **Minimum requirements**:
   - 2 GB RAM (4 GB recommended)
   - 10 GB free space
   - 2-4 CPU cores

2. **Optimal configuration**:
   - External MariaDB on host
   - 2-4 GB swap
   - Unnecessary services disabled

3. **Not recommended**:
   - Running more than 2-3 VMs simultaneously
   - VMs with more than 2 CPU cores
   - VMs with more than 2 GB RAM

## Support

For RISC-V issues:

1. Check logs:
```bash
docker compose logs
```

2. Check architecture:
```bash
uname -m  # Should be riscv64
```

3. Check Docker:
```bash
docker version
docker info | grep Architecture
```

4. Use external DB if Docker DB doesn't work

## Known Limitations

1. **Node.js**: Uses unofficial build, may be unstable
2. **MariaDB**: May run slower than on x86_64
3. **QEMU**: x86 VM emulation will be slow
4. **NPM**: Some packages may not have prebuilt binaries for RISC-V

## Successfully Tested On:

- ✅ Orange Pi RV2 (Allwinner D1)
- ⚠️ VisionFive 2 (partial)
- ⚠️ Milk-V Mars (partial)

## Feedback

If you successfully ran on another RISC-V platform, please let us know!

---

**Language versions:** [RISCV.EN.md](RISCV.EN.md) | [RISCV.RU.md](../RU/RISCV.RU.md)
