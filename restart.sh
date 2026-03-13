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
    ["restarting"]="Restarting QEMU Web Control..."
    ["restarted"]="Application restarted successfully"
    ["available_at"]="Application is available at"
    ["http"]="HTTP:"
    ["https"]="HTTPS:"
    ["error"]="Failed to restart application"
    ["port_conflict"]="Port conflict detected"
    ["fixing_ports"]="Attempting to fix port conflict..."
    ["manual_fix"]="Please run: ./scripts/fix-port-conflict.sh"
)

declare -A MESSAGES_RU=(
    ["restarting"]="Перезапуск QEMU Web Control..."
    ["restarted"]="Приложение успешно перезапущено"
    ["available_at"]="Приложение доступно по адресу"
    ["http"]="HTTP:"
    ["https"]="HTTPS:"
    ["error"]="Не удалось перезапустить приложение"
    ["port_conflict"]="Обнаружен конфликт портов"
    ["fixing_ports"]="Попытка исправить конфликт портов..."
    ["manual_fix"]="Пожалуйста, запустите: ./scripts/fix-port-conflict.sh"
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

restart_server() {
    print_info "${MESSAGES[restarting]}"
    
    # Определяем команду docker compose
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
    fi
    
    if $compose_cmd restart; then
        print_success "${MESSAGES[restarted]}"
        
        if [ -f .env ]; then
            APP_PORT=$(grep -E '^APP_PORT=' .env | cut -d '=' -f2)
            APP_SSL_PORT=$(grep -E '^APP_SSL_PORT=' .env | cut -d '=' -f2)
            APP_PORT=${APP_PORT:-8080}
            APP_SSL_PORT=${APP_SSL_PORT:-8443}
            echo ""
            print_info "${MESSAGES[available_at]}:"
            print_success "  ${MESSAGES[http]}  http://localhost:${APP_PORT}"
            print_success "  ${MESSAGES[https]} https://localhost:${APP_SSL_PORT}"
        fi
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
    restart_server
}

main "$@"
