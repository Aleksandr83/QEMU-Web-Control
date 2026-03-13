#!/bin/bash
set -e
set -o pipefail

print_success() { echo -e "\033[0;32m✓ $1\033[0m"; }
print_error()   { echo -e "\033[0;31m✗ $1\033[0m"; }
print_info()    { echo -e "\033[0;36m➜ $1\033[0m"; }
print_warning() { echo -e "\033[0;33m⚠ $1\033[0m"; }

get_main_interface() {
    local gw_dev
    gw_dev=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    if [ -n "$gw_dev" ]; then
        echo "$gw_dev"
        return
    fi
    ip -4 addr show 2>/dev/null | awk -F': ' '/state UP/ {print $2; exit}'
}

interface_in_bridge() {
    [ -L "/sys/class/net/$1/master" ] 2>/dev/null
}

restart_network_service() {
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        print_info "Restarting NetworkManager..."
        sudo systemctl restart NetworkManager 2>/dev/null || true
    elif systemctl is-active systemd-networkd >/dev/null 2>&1; then
        print_info "Restarting systemd-networkd..."
        sudo systemctl restart systemd-networkd 2>/dev/null || true
    fi
}

main() {
    local assume_yes=false
    [ "$1" = "--yes" ] || [ "$1" = "-y" ] || [ "${FORCE_YES}" = "1" ] && assume_yes=true

    if ! command -v ip >/dev/null 2>&1; then
        print_error "ip command not found"
        exit 1
    fi

    local iface
    iface=$(get_main_interface)
    if [ -z "$iface" ]; then
        print_error "Could not detect main network interface"
        exit 1
    fi

    if interface_in_bridge "$iface"; then
        local master
        master=$(readlink "/sys/class/net/$iface/master" 2>/dev/null | sed 's|.*/||')
        print_success "Interface $iface is already in bridge $master"
        exit 0
    fi

    if ! ip -4 addr show dev "$iface" 2>/dev/null | grep -q "inet "; then
        print_warning "Interface $iface has no IP."
        exit 0
    fi

    local br_name="br-${iface}"
    if [ "$assume_yes" != "true" ]; then
        print_warning "Interface $iface has an IP. Creating a bridge will reconfigure the network."
        print_warning "You may lose SSH connection for a few seconds. Prefer running from local console."
        echo ""
        read -r -p "Create bridge $br_name? [Y/n] " reply < /dev/tty 2>/dev/null || reply=""
        if [[ "$reply" =~ ^[nN]$ ]]; then
            print_info "Cancelled."
            exit 0
        fi
    fi

    if ip link show "$br_name" >/dev/null 2>&1 || [ -d "/sys/class/net/$br_name" ]; then
        print_info "Bridge $br_name already exists. Adding $iface to it..."
        sudo ip addr flush dev "$iface"
        sudo ip link set "$iface" master "$br_name"
        sudo ip link set "$br_name" up
        sudo ip link set "$iface" up
        if command -v dhclient >/dev/null 2>&1; then
            print_info "Getting IP via DHCP on $br_name..."
            sudo dhclient -r "$iface" 2>/dev/null || true
            sudo dhclient "$br_name" 2>/dev/null || true
        elif command -v dhcpcd >/dev/null 2>&1; then
            sudo dhcpcd "$br_name" 2>/dev/null || true
        else
            print_warning "No dhclient/dhcpcd found. Assign IP to $br_name manually."
        fi
        restart_network_service
        print_success "Interface $iface added to bridge $br_name."
        exit 0
    fi

    print_info "Creating bridge $br_name..."
    sudo ip addr flush dev "$iface"
    add_err=$(sudo ip link add "$br_name" type bridge 2>&1) || true
    if [ -n "$add_err" ]; then
        if echo "$add_err" | grep -q "File exists"; then
            print_info "Bridge $br_name already exists. Adding $iface to it..."
            sudo ip link set "$iface" master "$br_name"
            sudo ip link set "$br_name" up
            sudo ip link set "$iface" up
            if command -v dhclient >/dev/null 2>&1; then
                print_info "Getting IP via DHCP on $br_name..."
                sudo dhclient -r "$iface" 2>/dev/null || true
                sudo dhclient "$br_name" 2>/dev/null || true
            elif command -v dhcpcd >/dev/null 2>&1; then
                sudo dhcpcd "$br_name" 2>/dev/null || true
            else
                print_warning "No dhclient/dhcpcd found. Assign IP to $br_name manually."
            fi
            restart_network_service
            print_success "Interface $iface added to bridge $br_name."
            exit 0
        fi
        print_error "Failed to create bridge $br_name: $add_err"
        exit 1
    fi
    sudo ip link set "$iface" master "$br_name"
    sudo ip link set "$br_name" up
    sudo ip link set "$iface" up

    if command -v dhclient >/dev/null 2>&1; then
        print_info "Getting IP via DHCP on $br_name..."
        sudo dhclient -r "$iface" 2>/dev/null || true
        sudo dhclient "$br_name" 2>/dev/null || true
    elif command -v dhcpcd >/dev/null 2>&1; then
        sudo dhcpcd "$br_name" 2>/dev/null || true
    else
        print_warning "No dhclient/dhcpcd found. Assign IP to $br_name manually."
    fi

    restart_network_service
    print_success "Bridge $br_name created."
}

main "$@"
