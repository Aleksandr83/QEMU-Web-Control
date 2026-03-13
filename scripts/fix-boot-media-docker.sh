#!/bin/bash
# Fix Boot Media service connection from Docker containers.
# Run: sudo ./scripts/fix-boot-media-docker.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Boot Media Docker connection fix ==="

cd "$PROJECT_DIR"
docker compose up -d 2>/dev/null || true

GATEWAY=$(docker run --rm --network qemu_qemu_network alpine sh -c 'ip route 2>/dev/null | grep default | awk "{print \$3}"' 2>/dev/null || true)
if [ -z "$GATEWAY" ]; then
    SUBNET=$(docker network inspect qemu_qemu_network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null | head -1)
    if [ -n "$SUBNET" ]; then
        GATEWAY=$(echo "$SUBNET" | sed 's|/.*||;s|\.[0-9]*$|.1|')
    fi
fi
if [ -z "$GATEWAY" ]; then
    GATEWAY="172.17.0.1"
    echo "Using default gateway: $GATEWAY"
fi

echo "Docker network gateway: $GATEWAY"

SUBNET=$(docker network inspect qemu_qemu_network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
if [ -z "$SUBNET" ]; then
    SUBNET="172.17.0.0/16"
    echo "Using default subnet $SUBNET for firewall rule"
else
    echo "Docker network subnet: $SUBNET"
fi

if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    echo "Adding UFW rules: allow from $SUBNET to ports 50052, 50054, 50055"
    ufw allow from "$SUBNET" to any port 50052 comment "QemuBootImagesControlService from Docker"
    ufw allow from "$SUBNET" to any port 50054 comment "QemuControlService from Docker"
    ufw allow from "$SUBNET" to any port 50055 comment "QemuControlService VNC proxy from Docker"
    ufw reload
    echo "UFW rules added."
elif [ -w /etc/iptables/rules.v4 ] 2>/dev/null; then
    echo "Add iptables rule manually if needed."
else
    for port in 50052 50054 50055; do
        echo "Checking iptables INPUT for port $port..."
        if iptables -C INPUT -s "$SUBNET" -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            echo "Rule for $port already exists."
        else
            echo "Adding iptables rule: allow from $SUBNET to port $port"
            iptables -I INPUT -s "$SUBNET" -p tcp --dport "$port" -j ACCEPT
            echo "Rule for $port added."
        fi
    done
    echo "To make persistent: iptables-save | sudo tee /etc/iptables/rules.v4"
fi

ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    if grep -qE '^BOOT_MEDIA_SERVICE_URL=' "$ENV_FILE"; then
        sed -i "s|^BOOT_MEDIA_SERVICE_URL=.*|BOOT_MEDIA_SERVICE_URL=http://${GATEWAY}:50052|" "$ENV_FILE"
    else
        echo "BOOT_MEDIA_SERVICE_URL=http://${GATEWAY}:50052" >> "$ENV_FILE"
    fi
    if grep -qE '^QEMU_CONTROL_SERVICE_URL=' "$ENV_FILE"; then
        sed -i "s|^QEMU_CONTROL_SERVICE_URL=.*|QEMU_CONTROL_SERVICE_URL=http://${GATEWAY}:50054|" "$ENV_FILE"
    else
        echo "QEMU_CONTROL_SERVICE_URL=http://${GATEWAY}:50054" >> "$ENV_FILE"
    fi
    if grep -qE '^VNC_PROXY_VIA_QEMU_CONTROL=' "$ENV_FILE"; then
        sed -i 's|^VNC_PROXY_VIA_QEMU_CONTROL=.*|VNC_PROXY_VIA_QEMU_CONTROL=true|' "$ENV_FILE"
    else
        echo "VNC_PROXY_VIA_QEMU_CONTROL=true" >> "$ENV_FILE"
    fi
    echo "Updated .env: BOOT_MEDIA_SERVICE_URL, QEMU_CONTROL_SERVICE_URL, VNC_PROXY_VIA_QEMU_CONTROL"
fi

echo ""
echo "Restart app container: docker compose restart app"
