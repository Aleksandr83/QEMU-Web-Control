#!/bin/bash
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/safe-rm.sh"

INSTALL_LOG="${INSTALL_LOG:-${SCRIPT_DIR}/install-control-service.log}"

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

install_log_section "QemuControlService"

SERVICE_DIR="${SCRIPT_DIR}/services/QemuControlService"
if [ ! -d "$SERVICE_DIR" ]; then
    install_log "QemuControlService directory not found, skipping"
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
    safe_rm_rf --sudo "$BUILD_DIR"
    install_log "Cleaned QemuControlService build directory (safe_rm_rf --sudo)"
fi

print_info "Building QemuControlService..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if ! cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local 2>&1 | tee -a "$INSTALL_LOG"; then
    print_warning "QemuControlService cmake failed, skipping"
    install_log "QemuControlService cmake failed"
    cd "$SCRIPT_DIR"
    exit 0
fi

if ! cmake --build . -j"$(nproc 2>/dev/null || echo 4)" 2>&1 | tee -a "$INSTALL_LOG"; then
    print_warning "QemuControlService build failed, skipping"
    install_log "QemuControlService build failed"
    cd "$SCRIPT_DIR"
    exit 0
fi

print_info "Running QemuControlService tests..."
if ctest --output-on-failure 2>&1 | tee -a "$INSTALL_LOG"; then
    print_success "QemuControlService tests passed"
    install_log "QemuControlService tests passed"
else
    print_warning "QemuControlService tests failed, continuing"
    install_log "QemuControlService tests failed"
fi

if systemctl is-active --quiet QemuControlService.service 2>/dev/null; then
    sudo systemctl stop QemuControlService.service 2>/dev/null || true
    install_log "Stopped QemuControlService for reinstall"
fi
sudo cmake --install . 2>&1 | tee -a "$INSTALL_LOG"
install_log "QemuControlService installed to /usr/local/bin"

qemu_bin=$(grep -E '^QEMU_BIN_PATH=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d '=' -f2-) || true
qemu_bin=${qemu_bin:-/usr/bin/qemu-system-x86_64}
vm_storage=$(grep -E '^QEMU_VM_STORAGE=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d '=' -f2-) || true
vm_storage=${vm_storage:-/var/lib/qemu/vms}
qmp_socket_dir=$(grep -E '^QEMU_QMP_SOCKET_DIR=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d '=' -f2-) || true
qmp_socket_dir=${qmp_socket_dir:-/var/qemu/qmp}

use_kvm="true"
if [ ! -r /dev/kvm ] 2>/dev/null; then
    use_kvm="false"
    install_log "KVM not available (/dev/kvm), using TCG software emulation (USE_KVM=false)"
fi

aavmf_code_path=""
for candidate in \
    "/usr/share/AAVMF/AAVMF_CODE.fd" \
    "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd" \
    "/usr/share/edk2/aarch64/QEMU_EFI.fd"; do
    if [ -f "$candidate" ]; then
        aavmf_code_path="$candidate"
        install_log "AAVMF firmware found: $candidate"
        break
    fi
done
aavmf_line=""
if [ -n "$aavmf_code_path" ]; then
    aavmf_line="AAVMF_CODE_PATH=${aavmf_code_path}"
else
    install_log "AAVMF firmware not found (ARM VMs will not boot from ISO)"
fi

riscv_bios_path=""
for candidate in \
    "/usr/share/qemu-efi-riscv64/RISCV_VIRT_CODE.fd" \
    "/usr/share/edk2/riscv64/QEMU_EFI.fd"; do
    if [ -f "$candidate" ]; then
        riscv_bios_path="$candidate"
        install_log "RISC-V EDK2 firmware found: $candidate"
        break
    fi
done
riscv_bios_line=""
if [ -n "$riscv_bios_path" ]; then
    riscv_bios_line="RISCV_BIOS_PATH=${riscv_bios_path}"
else
    install_log "RISC-V EDK2 firmware not found (RISC-V VMs will not show display)"
fi

qemu_control_conf="/etc/QemuWebControl/qemu-control.conf"
vnc_token_file="${SCRIPT_DIR}/storage/app/vnc-tokens.txt"
ssl_cert="${SCRIPT_DIR}/docker/nginx/ssl/server.crt"
ssl_key="${SCRIPT_DIR}/docker/nginx/ssl/server.key"
vnc_ssl_cert_line=""
vnc_ssl_key_line=""
if [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
    vnc_ssl_cert_line="VNC_SSL_CERT=${ssl_cert}"
    vnc_ssl_key_line="VNC_SSL_KEY=${ssl_key}"
    install_log "VNC SSL: using $ssl_cert"
fi
printf 'LISTEN_ADDRESS=0.0.0.0\nPORT=50053\nHTTP_PORT=50054\nLOG_PATH=/var/log/QemuControlService.log\nQEMU_BIN_PATH=%s\nVM_STORAGE=%s\nQMP_SOCKET_DIR=%s\nUSE_KVM=%s\nVNC_BIND_ADDRESS=0.0.0.0\nVNC_TOKEN_FILE=%s\nVNC_WS_PORT=50055\n%s\n%s\n%s\n%s\n' \
    "$qemu_bin" "$vm_storage" "$qmp_socket_dir" "$use_kvm" "$vnc_token_file" "$vnc_ssl_cert_line" "$vnc_ssl_key_line" "$aavmf_line" "$riscv_bios_line" \
    | sudo tee "$qemu_control_conf" > /dev/null
sudo chmod 644 "$qemu_control_conf"
install_log "Created $qemu_control_conf"

systemd_unit="${SERVICE_DIR}/QemuControlService.service"
if [ -f "$systemd_unit" ]; then
    sudo cp "$systemd_unit" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable QemuControlService.service 2>/dev/null || true
    sudo systemctl start QemuControlService.service 2>/dev/null || true
    install_log "QemuControlService systemd unit installed and started"
fi

if grep -q "network_mode.*host" "${SCRIPT_DIR}/docker-compose.yml" 2>/dev/null; then
    qemu_control_url="http://127.0.0.1:50054"
else
    qemu_control_url="http://host.docker.internal:50054"
fi
if [ -f "${SCRIPT_DIR}/.env" ]; then
    if grep -qE '^QEMU_USE_EXTERNAL=' "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s|^QEMU_USE_EXTERNAL=.*|QEMU_USE_EXTERNAL=true|" "${SCRIPT_DIR}/.env"
    else
        echo "QEMU_USE_EXTERNAL=true" >> "${SCRIPT_DIR}/.env"
    fi
    if grep -qE '^QEMU_CONTROL_SERVICE_URL=' "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s|^QEMU_CONTROL_SERVICE_URL=.*|QEMU_CONTROL_SERVICE_URL=${qemu_control_url}|" "${SCRIPT_DIR}/.env"
    else
        echo "QEMU_CONTROL_SERVICE_URL=${qemu_control_url}" >> "${SCRIPT_DIR}/.env"
    fi
    if grep -qE '^VNC_PROXY_VIA_QEMU_CONTROL=' "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s|^VNC_PROXY_VIA_QEMU_CONTROL=.*|VNC_PROXY_VIA_QEMU_CONTROL=true|" "${SCRIPT_DIR}/.env"
    else
        echo "VNC_PROXY_VIA_QEMU_CONTROL=true" >> "${SCRIPT_DIR}/.env"
    fi
    install_log "QEMU_USE_EXTERNAL=true, QEMU_CONTROL_SERVICE_URL=${qemu_control_url}"
fi

if ! grep -q "network_mode.*host" "${SCRIPT_DIR}/docker-compose.yml" 2>/dev/null; then
    fix_script="${SCRIPT_DIR}/scripts/fix-boot-media-docker.sh"
    if [ -f "$fix_script" ] && command -v docker &>/dev/null; then
        print_info "Configuring host services connection for Docker..."
        if sudo "$fix_script" 2>&1 | tee -a "$INSTALL_LOG"; then
            install_log "fix-boot-media-docker.sh completed (QemuControlService URL updated)"
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

print_success "QemuControlService installed"
cd "$SCRIPT_DIR"
install_log "Returned to project root"
