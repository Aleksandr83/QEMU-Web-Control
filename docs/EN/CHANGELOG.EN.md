# Changelog

## [0.0.3] - 2026-03-16

### Added
- **Bridge network: select network interface** — In VM settings (create/edit) for bridge mode, you can now choose a physical network interface (e.g. enp0s3). The interface is stored in the database; on VM start, the service resolves the bridge containing that interface via `bridge link show`.
- **Logs tab: QemuControlService** — New "QemuControlService" tab on the Logs page shows the last 500 lines of the C++ service log (via HTTP GET /logs). Auto-refresh every 5 seconds, copy button, log clearing.

### Changed
- **Interface list** — GET /interfaces returns only physical adapters; virtual interfaces (lo, veth*, docker*, virbr*, vnet*, br-*, tap*, tun*) are excluded.
- **Bridge resolution** — Interface list is built from `ip link show`; bridge membership is looked up via `bridge link show`. Interfaces not in a bridge are also shown (with empty bridge).
- **Logging** — QemuControlService logs which bridge is used and how it was resolved (from interface, first bridge, or default br0).

### Fixed
- Bridge network mode: VMs with bridge type now start correctly; bridge list is loaded from the host.
- Blade template: missing `@endif` for `@if` in activity-logs index view.

## [0.0.2] - 2026-02-06

### ⚠️ Important Note

Installing on RISC-V (Orange Pi RV2):
- Build will take 20-30 minutes

### Added
- ✅ **VM autostart** on system boot
  - New `autostart` field in DB
  - Artisan command `vm:autostart`
  - Systemd service for autostart
  - Management script `autostart-service.sh`
  - Autostart indicator in UI
  - Documentation: `AUTOSTART.EN.md` / `AUTOSTART.RU.md`

- ✅ **RISC-V architecture support** (Orange Pi RV2, VisionFive, Milk-V)
  - Adapted Dockerfile for PHP with Node.js for RISC-V
  - Dockerfile for Nginx on Alpine
  - MariaDB support for RISC-V
  - Automatic `docker.io` installation on RISC-V
  - Documentation: `RISCV.EN.md` / `RISCV.RU.md`, `RISCV-QUICKSTART.EN.md` / `RISCV-QUICKSTART.RU.md`

- ✅ **docker-compose compatibility**
  - Support for `docker compose` (plugin)
  - Support for `docker-compose` (standalone)
  - Automatic detection of available version

- ✅ **install.sh improvements**
  - Automatic Apache2 reverse proxy setup
  - Automatic MySQL/MariaDB database creation
  - MySQL client check and installation
  - Database user privilege assignment

- ✅ **Documentation**
  - `COMMANDS.EN.md` / `COMMANDS.RU.md` - command reference (EN/RU)
  - `AUTOSTART.EN.md` / `AUTOSTART.RU.md` - autostart guide (EN/RU)
  - `RISCV.EN.md` / `RISCV.RU.md` - full RISC-V guide
  - `RISCV-QUICKSTART.EN.md` / `RISCV-QUICKSTART.RU.md` - RISC-V quick start
  - `APACHE.EN.md` / `APACHE.RU.md` - Apache2 reverse proxy setup
  - `TROUBLESHOOTING.EN.md` / `TROUBLESHOOTING.RU.md` - troubleshooting (IMPORTANT!)
  - `CHANGELOG.EN.md` / `CHANGELOG.RU.md` - changelog (EN/RU)
  - `diagnose.sh` - system diagnostics script

### Changed
- Improved Docker installation in `install.sh`
  - Automatic architecture detection
  - `docker.io` installation on RISC-V
  - Official Docker installation on x86_64/ARM64
  - Check for both docker-compose versions

- Updated all management scripts
  - `start.sh`, `stop.sh`, `restart.sh`, `uninstall.sh`
  - Automatic detection of `docker compose` vs `docker-compose`

- Updated documentation
  - `README.md` and `README.RU.md` with RISC-V info
  - `INSTALL.EN.md` / `INSTALL.RU.md` with RISC-V instruction links

### Fixed
- ❌ Docker installation error on RISC-V (package not found)
- ❌ "no matching manifest" error for Nginx and MariaDB on RISC-V
- ❌ Missing Node.js in container on RISC-V
- ❌ Incompatibility with different docker-compose versions

## [0.0.1] - 2026-02-06

### Added
- ✅ Initial QEMU Web Control release
- ✅ Laravel 11 with PHP 8.3
- ✅ Docker configuration (Nginx, PHP-FPM, MariaDB, Scheduler)
- ✅ Authentication and authorization system
- ✅ Role management (Administrator, User)
- ✅ CRUD for virtual machines
- ✅ VM management (start, stop, restart)
- ✅ Multi-language (English, Russian)
- ✅ Dark UI with Tailwind CSS
- ✅ Activity log
- ✅ SSL certificates (self-signed)
- ✅ Interactive installer `install.sh`
- ✅ Management scripts (start, stop, restart, uninstall)
- ✅ Sticky footer in all layouts
- ✅ System role protection
- ✅ Last administrator protection
- ✅ Correct Docker permissions (UID 1000)
- ✅ Bash script localization
- ✅ Formatted output with UTF-8 support

---

## Migration

### From 0.0.2 to 0.0.3

1. Update project files
2. Run migration:
```bash
docker compose exec app php artisan migrate
```
3. Rebuild QemuControlService (if built from source):
```bash
cd services/QemuControlService/build && cmake .. && make && sudo systemctl restart QemuControlService
```

### From 0.0.1 to 0.0.2

1. Update project files
2. Run new migration:
```bash
docker compose exec app php artisan migrate
```

3. If using RISC-V, rebuild images:
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

4. (Optional) Install autostart service:
```bash
./scripts/autostart-service.sh --install --lang ru
```

---

## Known Issues

### RISC-V
- Image build takes 20-30 minutes (this is normal)
- MariaDB may run slower than on x86_64
- Some NPM packages may not have prebuilt binaries

### General
- VNC for VMs requires additional setup
- x86 VM emulation on RISC-V is slow

---

## Future Plans

- [ ] Web VNC client for VM access
- [ ] User management via UI
- [ ] VM resource usage statistics
- [ ] VM snapshots
- [ ] VM cloning
- [ ] VM import/export
- [ ] REST API for management
---

## Acknowledgments

Thanks to everyone who tests and uses QEMU Web Control!

Special thanks to the RISC-V community for support and testing on Orange Pi RV2.
