#!/bin/bash
# Process delete requests for Boot Media ISO files.
# Run via cron or systemd timer with appropriate permissions.
# Example crontab: * * * * * /path/to/QemuWebControl/scripts/process-boot-media-deletions.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REQUESTS_FILE="${PROJECT_DIR}/storage/app/boot-media/delete-requests.json"

[[ -f "$REQUESTS_FILE" ]] || exit 0

cd "$PROJECT_DIR"
php artisan boot-media:process-deletions
