#!/bin/bash
set -e

echo "Fix: QEMU bridge.conf for bridge network mode"
echo ""

if [ ! -d /etc/qemu ]; then
    sudo mkdir -p /etc/qemu
    echo "Created /etc/qemu"
fi

BRIDGE_CONF="/etc/qemu/bridge.conf"
BRIDGE_NAME="${1:-all}"

printf 'allow %s\n' "$BRIDGE_NAME" | sudo tee "$BRIDGE_CONF" > /dev/null
sudo chmod 644 "$BRIDGE_CONF"
sudo chown root:root "$BRIDGE_CONF"

echo "Created $BRIDGE_CONF with: allow $BRIDGE_NAME"
echo ""
if [ "$BRIDGE_NAME" = "all" ]; then
    echo "Using 'allow all' - permits any bridge. For a specific bridge run:"
    echo "  $0 br0"
    echo "  $0 virbr0"
else
    echo "For 'allow all' run: $0 all"
fi
echo ""
echo "Restart containers: docker compose down && docker compose up -d"
