#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

LANG_CODE="en"

detect_language() {
    local sys_lang="${LANG:-en_US}"
    if [[ "$sys_lang" == ru_* ]]; then
        LANG_CODE="ru"
    fi
}

set_language() {
    case "$1" in
        ru|RU) LANG_CODE="ru" ;;
        *) LANG_CODE="en" ;;
    esac
}

declare -A MESSAGES_EN=(
    ["stopping"]="Stopping QEMU Web Control..."
    ["stopped"]="Application stopped successfully"
    ["error"]="Failed to stop application"
)

declare -A MESSAGES_RU=(
    ["stopping"]="Остановка QEMU Web Control..."
    ["stopped"]="Приложение успешно остановлено"
    ["error"]="Не удалось остановить приложение"
)

declare -A MESSAGES

load_messages() {
    if [[ "$LANG_CODE" == "ru" ]]; then
        for key in "${!MESSAGES_RU[@]}"; do
            MESSAGES[$key]="${MESSAGES_RU[$key]}"
        done
    else
        for key in "${!MESSAGES_EN[@]}"; do
            MESSAGES[$key]="${MESSAGES_EN[$key]}"
        done
    fi
}

print_success() {
    echo -e "\033[0;32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m✗ $1\033[0m"
}

print_info() {
    echo -e "\033[0;36m➜ $1\033[0m"
}

stop_server() {
    print_info "${MESSAGES[stopping]}"
    
    # Определяем команду docker compose
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
    fi
    
    if $compose_cmd stop; then
        if systemctl is-enabled QemuBootImagesControlService.service &>/dev/null; then
            sudo systemctl stop QemuBootImagesControlService.service 2>/dev/null || true
        fi
        if systemctl is-enabled QemuControlService.service &>/dev/null; then
            sudo systemctl stop QemuControlService.service 2>/dev/null || true
        fi
        print_success "${MESSAGES[stopped]}"
    else
        print_error "${MESSAGES[error]}"
        exit 1
    fi
}

main() {
    if [[ "$1" == "--lang" && -n "$2" ]]; then
        set_language "$2"
        shift 2
    else
        detect_language
    fi
    
    load_messages
    stop_server
}

main "$@"
