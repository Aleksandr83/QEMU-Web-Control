#!/bin/bash
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/safe-rm.sh"

INSTALL_LOG="${INSTALL_LOG:-${SCRIPT_DIR}/install-boot-images-service.log}"

install_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG"
}

install_log_section() {
    echo "" >> "$INSTALL_LOG"
    echo "========== $1 ==========" >> "$INSTALL_LOG"
    install_log "$1"
}

print_success() { echo -e "\033[0;32m✓ $1\033[0m"; }
print_error()   { echo -e "\033[0;31m✗ $1\033[0m"; }
print_info()    { echo -e "\033[0;36m➜ $1\033[0m"; }
print_warning() { echo -e "\033[0;33m⚠ $1\033[0m"; }

install_log_section "QemuBootImagesControlService"

SERVICE_DIR="${SCRIPT_DIR}/services/QemuBootImagesControlService"
if [ ! -d "$SERVICE_DIR" ]; then
    install_log "QemuBootImagesControlService directory not found, skipping"
    exit 0
fi

BUILD_DIR="${SERVICE_DIR}/build"
CHECKSUM_FILE="${BUILD_DIR}/checksum.txt"
SKIP_BUILD_CLEAN=false

if [ -f "$CHECKSUM_FILE" ]; then
    checksum1=$(cat "$CHECKSUM_FILE")
    install_log "Found existing build checksum: ${checksum1}"

    if bash "${SCRIPT_DIR}/scripts/sys-info-to-file.sh" "$BUILD_DIR" "sysinfo.txt" >> "$INSTALL_LOG" 2>&1; then
        bash "${SCRIPT_DIR}/scripts/get_file_sha256.sh" \
            --dir="$SERVICE_DIR" \
            --files="${BUILD_DIR}/sysinfo.txt" \
            --ignore_folders="build" \
            --output="$CHECKSUM_FILE" \
            --lang="${LANG_CODE:-en}" >> "$INSTALL_LOG" 2>&1 || true

        checksum2=$(cat "$CHECKSUM_FILE" 2>/dev/null || echo "")

        if [ -n "$checksum2" ] && [ "$checksum1" = "$checksum2" ]; then
            SKIP_BUILD_CLEAN=true
            install_log "Checksum match — reusing existing build directory"
            print_info "Build cache valid (checksum match), skipping rebuild"
        else
            install_log "Checksum mismatch — cleaning build directory"
            print_info "Source or system changed, rebuilding..."
        fi
    else
        install_log "sys-info-to-file.sh failed — falling back to clean build"
    fi
fi

if ! $SKIP_BUILD_CLEAN; then
    safe_rm_rf --sudo "$BUILD_DIR" \
               "${SCRIPT_DIR}/services/QemuControlService/build"
    install_log "Cleaned C++ build directories (safe_rm_rf --sudo)"
fi

if grep -q "network_mode.*host" "${SCRIPT_DIR}/docker-compose.yml" 2>/dev/null; then
    boot_service_url="http://127.0.0.1:50052"
else
    boot_service_url="http://host.docker.internal:50052"
fi
if [ -f "${SCRIPT_DIR}/.env" ]; then
    if grep -qE '^BOOT_MEDIA_SERVICE_URL=' "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s|^BOOT_MEDIA_SERVICE_URL=.*|BOOT_MEDIA_SERVICE_URL=${boot_service_url}|" "${SCRIPT_DIR}/.env"
    else
        echo "BOOT_MEDIA_SERVICE_URL=${boot_service_url}" >> "${SCRIPT_DIR}/.env"
    fi
    install_log "BOOT_MEDIA_SERVICE_URL=${boot_service_url} (Docker: use host for ISO delete)"
fi

print_info "Building QemuBootImagesControlService..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if ! cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local 2>&1 | tee -a "$INSTALL_LOG"; then
    print_warning "QemuBootImagesControlService cmake failed, skipping"
    install_log "QemuBootImagesControlService cmake failed"
    cd "$SCRIPT_DIR"
    exit 0
fi

if ! cmake --build . -j"$(nproc 2>/dev/null || echo 4)" 2>&1 | tee -a "$INSTALL_LOG"; then
    print_warning "QemuBootImagesControlService build failed, skipping"
    install_log "QemuBootImagesControlService build failed"
    cd "$SCRIPT_DIR"
    exit 0
fi

print_info "Running QemuBootImagesControlService tests..."
if ctest --output-on-failure 2>&1 | tee -a "$INSTALL_LOG"; then
    print_success "QemuBootImagesControlService tests passed"
    install_log "QemuBootImagesControlService tests passed"
else
    print_warning "QemuBootImagesControlService tests failed, continuing"
    install_log "QemuBootImagesControlService tests failed"
fi

if systemctl is-active --quiet QemuBootImagesControlService.service 2>/dev/null; then
    sudo systemctl stop QemuBootImagesControlService.service 2>/dev/null || true
    install_log "Stopped QemuBootImagesControlService for reinstall"
fi
sudo cmake --install . 2>&1 | tee -a "$INSTALL_LOG"
install_log "QemuBootImagesControlService installed to /usr/local/bin"

iso_dirs=$(grep -E '^QEMU_ISO_DIRECTORIES=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d '=' -f2-) || true
iso_dirs=${iso_dirs:-/var/lib/qemu/iso,/srv/iso}
staging_dir=$(grep -E '^QEMU_ISO_UPLOAD_STAGING=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d '=' -f2-) || true
staging_dir=${staging_dir:-/var/lib/qemu/iso-staging}
boot_media_conf="/etc/QemuWebControl/boot-media.conf"
printf 'ISO_DIRECTORIES=%s\nSTAGING_DIR=%s\nLISTEN_ADDRESS=0.0.0.0\nPORT=50051\nHTTP_PORT=50052\nLOG_PATH=/var/log/QemuBootImagesControlService.log\nRATE_LIMIT_MAX_REQUESTS=100\nRATE_LIMIT_WINDOW_SEC=60\n' \
    "$iso_dirs" "$staging_dir" | sudo tee "$boot_media_conf" > /dev/null
sudo chmod 644 "$boot_media_conf"
install_log "Created $boot_media_conf with ISO_DIRECTORIES=$iso_dirs"

systemd_unit="${SERVICE_DIR}/QemuBootImagesControlService.service"
if [ -f "$systemd_unit" ]; then
    sudo cp "$systemd_unit" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable QemuBootImagesControlService.service 2>/dev/null || true
    sudo systemctl start QemuBootImagesControlService.service 2>/dev/null || true
    install_log "QemuBootImagesControlService systemd unit installed and started"
fi

if ! grep -q "network_mode.*host" "${SCRIPT_DIR}/docker-compose.yml" 2>/dev/null; then
    fix_script="${SCRIPT_DIR}/scripts/fix-boot-media-docker.sh"
    if [ -f "$fix_script" ] && command -v docker &>/dev/null; then
        print_info "Configuring Boot Media connection for Docker..."
        if sudo "$fix_script" 2>&1 | tee -a "$INSTALL_LOG"; then
            install_log "fix-boot-media-docker.sh completed"
        else
            print_warning "fix-boot-media-docker.sh had issues, check manually"
        fi
    fi
fi

if bash "${SCRIPT_DIR}/scripts/sys-info-to-file.sh" "$BUILD_DIR" "sysinfo.txt" >> "$INSTALL_LOG" 2>&1; then
    bash "${SCRIPT_DIR}/scripts/get_file_sha256.sh" \
        --dir="$SERVICE_DIR" \
        --files="${BUILD_DIR}/sysinfo.txt" \
        --ignore_folders="build" \
        --output="${BUILD_DIR}/checksum.txt" \
        --lang="${LANG_CODE:-en}" >> "$INSTALL_LOG" 2>&1 || true
    install_log "Build checksum saved: $(cat "${BUILD_DIR}/checksum.txt" 2>/dev/null)"
else
    install_log "sys-info-to-file.sh failed — build checksum not saved"
fi

print_success "QemuBootImagesControlService installed"
cd "$SCRIPT_DIR"
install_log "Returned to project root"
