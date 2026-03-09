#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

print_info() { echo -e "\033[0;36m➜ $1\033[0m"; }
print_success() { echo -e "\033[0;32m✓ $1\033[0m"; }
print_error() { echo -e "\033[0;31m✗ $1\033[0m"; }

print_info "Running PHPUnit tests..."

compose_cmd="docker compose"
if ! docker compose version &>/dev/null 2>&1; then
    compose_cmd="docker-compose"
fi

if $compose_cmd ps 2>/dev/null | grep -q "app.*Up"; then
    $compose_cmd exec -T app php artisan test "$@"
else
    php artisan test "$@"
fi

print_success "Tests completed"
