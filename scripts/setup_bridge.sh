#!/bin/bash
set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_LOG="${INSTALL_LOG:-}"

install_log() {
    [ -n "$INSTALL_LOG" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG" || true
}

print_success() { echo -e "\033[0;32m✓ $1\033[0m"; }
print_info()    { echo -e "\033[0;36m➜ $1\033[0m"; }
print_warning() { echo -e "\033[0;33m⚠ $1\033[0m"; }

is_physical_interface() {
    local name="$1"
    [ -z "$name" ] && return 1
    case "$name" in
        lo) return 1 ;;
        veth*) return 1 ;;
        docker*) return 1 ;;
        virbr*) return 1 ;;
        vnet*) return 1 ;;
        br-*) return 1 ;;
        tap*) return 1 ;;
        tun*) return 1 ;;
        *) return 0 ;;
    esac
}

interface_in_bridge() {
    local iface="$1"
    [ -z "$iface" ] && return 1
    [ -L "/sys/class/net/$iface/master" ] 2>/dev/null && return 0
    return 1
}

interface_has_ip() {
    local iface="$1"
    [ -z "$iface" ] && return 1
    ip -4 addr show dev "$iface" 2>/dev/null | grep -q "inet "
    return $?
}

main() {
    install_log "setup_bridge: starting"
    print_info "Setting up bridges for physical interfaces..."

    if ! command -v ip >/dev/null 2>&1; then
        print_warning "ip command not found, skipping bridge setup"
        install_log "setup_bridge: ip not found, skipped"
        return 0
    fi

    local created=0
    while IFS= read -r line; do
        local iface
        iface=$(echo "$line" | sed -n 's/^[0-9]*: \([^:]*\):.*/\1/p' | tr -d ' ')
        [ -z "$iface" ] && continue
        is_physical_interface "$iface" || continue

        if interface_in_bridge "$iface"; then
            install_log "setup_bridge: $iface already in a bridge, skip"
            continue
        fi

        if interface_has_ip "$iface"; then
            install_log "setup_bridge: $iface has IP, skip (will be prompted at end of install)"
            continue
        fi

        local br_name="br-${iface}"
        if ip link show "$br_name" >/dev/null 2>&1; then
            install_log "setup_bridge: bridge $br_name exists, adding $iface"
        else
            if ! sudo ip link add "$br_name" type bridge 2>/dev/null; then
                install_log "setup_bridge: failed to create $br_name"
                continue
            fi
            install_log "setup_bridge: created $br_name"
        fi

        if sudo ip link set "$iface" master "$br_name" 2>/dev/null; then
            sudo ip link set "$br_name" up 2>/dev/null || true
            sudo ip link set "$iface" up 2>/dev/null || true
            install_log "setup_bridge: added $iface to $br_name"
            print_success "Bridge $br_name: added $iface"
            created=$((created + 1))
        else
            install_log "setup_bridge: failed to add $iface to $br_name"
        fi
    done < <(ip -o link show 2>/dev/null)

    if [ "$created" -eq 0 ] 2>/dev/null; then
        print_info "No new bridges created (all physical interfaces already in bridges or have IP)"
    fi
    if [ "$created" -gt 0 ] 2>/dev/null; then
        if systemctl is-active NetworkManager >/dev/null 2>&1; then
            sudo systemctl restart NetworkManager 2>/dev/null || true
            install_log "setup_bridge: restarted NetworkManager"
        elif systemctl is-active systemd-networkd >/dev/null 2>&1; then
            sudo systemctl restart systemd-networkd 2>/dev/null || true
            install_log "setup_bridge: restarted systemd-networkd"
        fi
    fi
    install_log "setup_bridge: done"
}

main "$@"
