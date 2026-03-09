#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/safe-rm.sh
source "${SCRIPT_DIR}/scripts/safe-rm.sh" 2>/dev/null || true

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
    ["starting"]="Starting QEMU Web Control..."
    ["started"]="Application started successfully"
    ["available_at"]="Application is available at"
    ["http"]="HTTP:"
    ["https"]="HTTPS:"
    ["error"]="Failed to start application"
    ["port_conflict"]="Port conflict detected"
    ["fixing_ports"]="Attempting to fix port conflict..."
    ["retry"]="Retrying with new ports..."
    ["manual_fix"]="Please run: ./scripts/fix-port-conflict.sh"
)

declare -A MESSAGES_RU=(
    ["starting"]="Запуск QEMU Web Control..."
    ["started"]="Приложение успешно запущено"
    ["available_at"]="Приложение доступно по адресу"
    ["http"]="HTTP:"
    ["https"]="HTTPS:"
    ["error"]="Не удалось запустить приложение"
    ["port_conflict"]="Обнаружен конфликт портов"
    ["fixing_ports"]="Попытка исправить конфликт портов..."
    ["retry"]="Повторная попытка с новыми портами..."
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

print_warning() {
    echo -e "\033[0;33m⚠ $1\033[0m"
}

check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

find_free_port() {
    local start_port=$1
    local port=$start_port
    
    while check_port $port && [ $port -lt 9000 ]; do
        port=$((port + 1))
    done
    
    echo $port
}

start_server() {
    print_info "${MESSAGES[starting]}"

    if systemctl is-enabled QemuBootImagesControlService.service &>/dev/null; then
        sudo systemctl start QemuBootImagesControlService.service 2>/dev/null || true
    fi
    if systemctl is-enabled QemuControlService.service &>/dev/null; then
        sudo systemctl start QemuControlService.service 2>/dev/null || true
    fi
    
    # Определяем команду docker compose
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
    fi
    
    # Попытка запуска
    if $compose_cmd up -d 2>&1 | tee /tmp/start_output.log; then
        # Проверяем на ошибку порта
        if grep -q "address already in use" /tmp/start_output.log; then
            print_warning "${MESSAGES[port_conflict]}"
            print_info "${MESSAGES[fixing_ports]}"
            
            # Останавливаем контейнеры
            $compose_cmd down 2>/dev/null
            
            if [ -f .env ]; then
                local new_port=$(find_free_port 8081)
                local new_ssl_port=$(find_free_port 8444)
                
                sed -i "s/APP_PORT=.*/APP_PORT=$new_port/" .env
                sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=$new_ssl_port/" .env
                
                print_success "Ports updated: HTTP=$new_port, HTTPS=$new_ssl_port"
                print_info "${MESSAGES[retry]}"
                
                if $compose_cmd up -d; then
                    print_success "${MESSAGES[started]}"
                    
                    echo ""
                    print_info "${MESSAGES[available_at]}:"
                    print_success "  ${MESSAGES[http]}  http://localhost:${new_port}"
                    print_success "  ${MESSAGES[https]} https://localhost:${new_ssl_port}"
                    
                    safe_rm_f /tmp/start_output.log 2>/dev/null || rm -f /tmp/start_output.log
                    return 0
                else
                    print_error "${MESSAGES[error]}"
                    echo ""
                    print_info "${MESSAGES[manual_fix]}"
                    safe_rm_f /tmp/start_output.log 2>/dev/null || rm -f /tmp/start_output.log
                    exit 1
                fi
            else
                print_error "${MESSAGES[error]}"
                print_info "${MESSAGES[manual_fix]}"
                safe_rm_f /tmp/start_output.log 2>/dev/null || rm -f /tmp/start_output.log
                exit 1
            fi
        else
            # Успешный запуск
            print_success "${MESSAGES[started]}"
            
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
        fi
    else
        print_error "${MESSAGES[error]}"
        echo ""
        print_info "${MESSAGES[manual_fix]}"
        exit 1
    fi
    
    safe_rm_f /tmp/start_output.log 2>/dev/null || rm -f /tmp/start_output.log
}

main() {
    if [[ "$1" == "--lang" && -n "$2" ]]; then
        set_language "$2"
        shift 2
    else
        detect_language
    fi
    
    load_messages
    start_server
}

main "$@"
