# QEMU Web Control Quick Installation

## Requirements
- Linux (Debian/Ubuntu, Orange Pi RV2)
- Docker (installed automatically)
- QEMU/KVM on host

**For RISC-V (Orange Pi, VisionFive)**: See [RISCV-QUICKSTART.EN.md](RISCV-QUICKSTART.EN.md) / [RISCV-QUICKSTART.RU.md](../RU/RISCV-QUICKSTART.RU.md)

## Installation

```bash
# Clone or navigate to project directory
cd QemuWebControl

# Run installation
chmod +x install.sh
./install.sh

# Or in Russian
./install.sh --lang ru
```

**⚠️ Important for RISC-V:**
- Installation takes 20-30 minutes
- Image build is the longest part
- If something fails - see [TROUBLESHOOTING.EN.md](TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](../RU/TROUBLESHOOTING.RU.md)

**💡 Tip:**
- Default values are shown in `[square brackets]` when entering parameters
- Just press Enter to use the default value
- Installation examples: [INSTALL-EXAMPLE.EN.md](INSTALL-EXAMPLE.EN.md) / [INSTALL-EXAMPLE.RU.md](../RU/INSTALL-EXAMPLE.RU.md)

## After installation

Application will be available at:
- HTTP: http://localhost:8080
- HTTPS: https://localhost:8443

### Credentials

**Administrator:**
- Login: admin
- Password: admin

## Database selection

Two options available during installation:

**[1] Docker MariaDB** (x86_64, amd64, aarch64)
- MariaDB runs in separate container
- Database created automatically
- No MariaDB installation on host required
- **Not supported on RISC-V** (Orange Pi, VisionFive)

**[2] External MariaDB/MySQL**
- Uses existing MariaDB/MySQL on host
- Modes: Host Network (localhost) or Bridge (gateway IP)
- Required on RISC-V
- Recommended for production (security)

## Management

```bash
./start.sh      # Start
./stop.sh       # Stop
./restart.sh    # Restart
./uninstall.sh  # Uninstall
```

## Useful scripts

```bash
./scripts/diagnose.sh          # System diagnostics
./scripts/setup-database.sh    # Database setup
./scripts/autostart-service.sh # VM autostart management
```

## QEMU configuration

Installer creates directories `/var/qemu/VM`, `/var/lib/qemu/iso`, `/srv/iso`.

Copy ISO images to `/var/lib/qemu/iso/` or `/srv/iso/`. When creating VM, specify ISO path, e.g.: `/var/lib/qemu/iso/ubuntu.iso`.

## VM autostart setup (optional)

If you want VMs with autostart enabled to start on system boot:

```bash
# Install autostart service
./scripts/autostart-service.sh --install --lang ru

# Check status
./scripts/autostart-service.sh --status

# Mark desired VMs for autostart in web interface
```

## Detailed documentation

- [English README](../../README.md)
- [Russian documentation](../../README.RU.md)

---

**Language versions:** [INSTALL.EN.md](INSTALL.EN.md) | [INSTALL.RU.md](../RU/INSTALL.RU.md)
