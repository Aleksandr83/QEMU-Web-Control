# QEMU Web Control

Modern web interface for managing QEMU virtual machines built with Laravel 11, Docker, and Tailwind CSS.

![plot](./resources/images/screenshots.png)

## Features

- 🖥️ **Virtual Machine Management**: Create, start, stop, restart, and delete QEMU VMs
- 🔐 **Authentication & Authorization**: Role-based access control (Administrator/User)
- 🌍 **Multi-language Support**: English and Russian languages
- 🎨 **Modern Dark UI**: Beautiful dark theme with Tailwind CSS
- 📊 **Activity Logging**: Comprehensive audit logs for all actions
- 🔒 **SSL Support**: HTTPS with self-signed or Let's Encrypt certificates
- 🐳 **Docker Integration**: Easy deployment with Docker Compose
- 📦 **MariaDB Storage**: Reliable database for configuration storage

## Requirements

- Linux host (tested on Debian/Ubuntu, Orange Pi RV2)
- Docker & Docker Compose (will be installed automatically if missing)
- QEMU/KVM installed on the host system

**Note for RISC-V**: If you're using RISC-V architecture (Orange Pi, VisionFive, etc.), see [RISCV.EN.md](docs/EN/RISCV.EN.md) / [RISCV.RU.md](docs/RU/RISCV.RU.md) or [RISCV-QUICKSTART.EN.md](docs/EN/RISCV-QUICKSTART.EN.md) / [RISCV-QUICKSTART.RU.md](docs/RU/RISCV-QUICKSTART.RU.md) for special instructions.

## Quick Installation

```bash
chmod +x install.sh
./install.sh
```

The installer will:
1. Check and install Docker if needed
2. Set up the database (Docker or external)
3. Configure the environment
4. Generate SSL certificates
5. Build and start containers
6. Run migrations and seeders

## Management Scripts

```bash
./start.sh      # Start the application
./stop.sh       # Stop the application
./restart.sh    # Restart the application
./uninstall.sh  # Uninstall the application
```

All scripts support `--lang ru` or `--lang en` parameter.

## Default Access

After installation:
- **URL**: http://localhost:8080 or https://localhost:8443 (if ports are occupied, alternatives will be suggested)
- **Admin**: admin / admin

## Configuration

### QEMU Storage

The installer creates these directories automatically:
- VM disks: `/var/qemu/VM`
- ISO images: `/var/lib/qemu/iso` or `/srv/iso`

For CD-ROM, specify the ISO path when creating/editing a VM, e.g. `/var/lib/qemu/iso/ubuntu.iso` or `/srv/iso/ubuntu.iso`. Use `QEMU_ISO_VOLUME` in `.env` for a custom ISO path. ISO files can be uploaded via web interface (Settings → Boot Media, up to 10 GB) — see [BOOT-MEDIA.EN.md](docs/EN/BOOT-MEDIA.EN.md).

## Autostart Virtual Machines

Virtual machines with the "Autostart" option enabled will automatically start when the system boots.

### Install Autostart Service

```bash
# Install service
./scripts/autostart-service.sh --install

# Check status
./scripts/autostart-service.sh --status

# Uninstall service
./scripts/autostart-service.sh --uninstall
```

### Manual Autostart

```bash
# Start all VMs marked for autostart
docker compose exec app php artisan vm:autostart
```

## Technology Stack

- **Backend**: Laravel 11, PHP 8.3
- **Frontend**: Tailwind CSS
- **Database**: MariaDB 11.2
- **Web Server**: Nginx (Alpine)
- **Containerization**: Docker & Docker Compose

## AI Tools

AI tools were used when creating the project:

- [Cursor AI](https://cursor.com/home)

## License

MIT License
