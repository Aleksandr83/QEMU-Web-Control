# Boot Media

ISO images for installing and booting operating systems in virtual machines.

## Overview

The Boot Media section (Settings → Boot Media) shows all ISO images available in the configured directories. Use these images when creating or editing a VM to boot from CD-ROM.

## Directories

By default, the application scans:

- `/var/lib/qemu/iso`
- `/srv/iso`

Configure custom paths in `.env`:

```
QEMU_ISO_DIRECTORIES=/var/lib/qemu/iso,/srv/iso,/path/to/custom
```

## Adding ISO Images

**Option 1: Upload via web interface**

If at least one directory from `QEMU_ISO_DIRECTORIES` is writable, the upload form is shown:

1. Go to Settings → Boot Media
2. Select target directory (if several are writable)
3. Click "Browse" and select an ISO file
4. Wait for the upload to complete (progress bar shows stage: uploading to temp → moving to target)

**Upload limits:** Files up to 10 GB (requires sufficient free space on staging and target directories). PHP and Nginx are configured for 10 GB by `install.sh`.

**Errors:** Upload failures (insufficient space, move error, etc.) are logged to Settings → Logs → Errors tab.

**Option 2: Copy manually**

1. Copy ISO files to one of the directories (e.g. `/var/lib/qemu/iso/` or `/srv/iso/`)
2. Click "Refresh list" or reload the page to see new files

When creating a VM, select the directory and file from the dropdown.

## Download

Click the download icon to save an ISO to your computer. Supports resumable downloads (HTTP Range).

## Delete

Click the delete icon to remove an ISO. Deletion is handled by **QemuBootImagesControlService** (C++ gRPC/HTTP service) running on the host. The service must be started before the web app can delete files.

**Important:** The C++ service runs on the host. For Docker, `BOOT_MEDIA_SERVICE_URL` in `.env` must point to the host:

- Host network: `http://127.0.0.1:50052`
- `http://host.docker.internal:50052` (recommended, works on Linux and Docker Desktop)
- `http://172.17.0.1:50052` (Docker bridge gateway)

`install.sh` sets this automatically. The service is started/stopped by `start.sh` and `stop.sh`.

If connection from Docker fails (cURL error 7), run:

```bash
sudo ./scripts/fix-boot-media-docker.sh
sudo docker compose restart app
```

If the service is unavailable, the app falls back to direct `unlink` or queues the request. Process the queue with:

```bash
php artisan boot-media:process-deletions
```

Or add to crontab: `* * * * * /path/to/QemuWebControl/scripts/process-boot-media-deletions.sh`

## Docker

When running in Docker, ISO directories are mounted from the host. Ensure the host paths exist and contain your ISO files:

```yaml
volumes:
  - ${QEMU_ISO_VOLUME:-/var/lib/qemu/iso}:/var/lib/qemu/iso:ro
  - /srv/iso:/srv/iso:ro
```

By default, directories are read-only (`:ro`). To enable upload via web interface, mount at least one directory as writable (remove `:ro`).
