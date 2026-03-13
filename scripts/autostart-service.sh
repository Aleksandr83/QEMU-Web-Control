#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
SCRIPT_DIR="$PROJECT_DIR" source "${PROJECT_DIR}/scripts/safe-rm.sh" 2>/dev/null || true

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
    ["installing"]="Installing autostart service..."
    ["service_file"]="Creating systemd service file..."
    ["enabling"]="Enabling service..."
    ["success"]="Autostart service installed successfully"
    ["test"]="Testing autostart command..."
    ["test_success"]="Autostart command works correctly"
    ["manual_steps"]="Manual steps to complete installation:"
    ["step1"]="1. Edit the service file and update paths:"
    ["step2"]="   sudo nano /etc/systemd/system/qemu-autostart.service"
    ["step3"]="2. Update WorkingDirectory to your project path"
    ["step4"]="3. Update User and Group to your username"
    ["step5"]="4. Reload systemd and enable the service:"
    ["step6"]="   sudo systemctl daemon-reload"
    ["step7"]="   sudo systemctl enable qemu-autostart.service"
    ["uninstalling"]="Uninstalling autostart service..."
    ["uninstall_success"]="Autostart service uninstalled successfully"
    ["status"]="Checking autostart service status..."
    ["not_installed"]="Autostart service is not installed"
)

declare -A MESSAGES_RU=(
    ["installing"]="Установка службы автозапуска..."
    ["service_file"]="Создание файла службы systemd..."
    ["enabling"]="Включение службы..."
    ["success"]="Служба автозапуска успешно установлена"
    ["test"]="Тестирование команды автозапуска..."
    ["test_success"]="Команда автозапуска работает корректно"
    ["manual_steps"]="Ручные шаги для завершения установки:"
    ["step1"]="1. Отредактируйте файл службы и обновите пути:"
    ["step2"]="   sudo nano /etc/systemd/system/qemu-autostart.service"
    ["step3"]="2. Обновите WorkingDirectory на путь к вашему проекту"
    ["step4"]="3. Обновите User и Group на ваше имя пользователя"
    ["step5"]="4. Перезагрузите systemd и включите службу:"
    ["step6"]="   sudo systemctl daemon-reload"
    ["step7"]="   sudo systemctl enable qemu-autostart.service"
    ["uninstalling"]="Удаление службы автозапуска..."
    ["uninstall_success"]="Служба автозапуска успешно удалена"
    ["status"]="Проверка статуса службы автозапуска..."
    ["not_installed"]="Служба автозапуска не установлена"
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

install_service() {
    print_info "${MESSAGES[installing]}"
    
    # Определяем команду docker compose
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
    fi
    
    print_info "${MESSAGES[test]}"
    if $compose_cmd exec -T app php artisan vm:autostart > /dev/null 2>&1; then
        print_success "${MESSAGES[test_success]}"
    else
        print_error "Failed to run autostart command"
        exit 1
    fi
    
    print_info "${MESSAGES[service_file]}"
    
    # Определяем полный путь к docker compose
    local docker_compose_path="/usr/bin/docker"
    if command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        docker_compose_path=$(which docker-compose)
        cat > qemu-autostart.service.tmp << EOF
[Unit]
Description=QEMU Web Control - Autostart Virtual Machines
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=${docker_compose_path} exec -T app php artisan vm:autostart
User=$(whoami)
Group=$(id -gn)

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > qemu-autostart.service.tmp << EOF
[Unit]
Description=QEMU Web Control - Autostart Virtual Machines
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker compose exec -T app php artisan vm:autostart
User=$(whoami)
Group=$(id -gn)

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    sudo cp qemu-autostart.service.tmp /etc/systemd/system/qemu-autostart.service
    safe_rm_f "${PROJECT_DIR}/qemu-autostart.service.tmp" 2>/dev/null || rm -f qemu-autostart.service.tmp
    
    print_info "${MESSAGES[enabling]}"
    sudo systemctl daemon-reload
    sudo systemctl enable qemu-autostart.service
    
    print_success "${MESSAGES[success]}"
    echo ""
    print_info "Service will start VMs on next system boot"
    print_info "To test now: sudo systemctl start qemu-autostart.service"
}

uninstall_service() {
    print_info "${MESSAGES[uninstalling]}"
    
    sudo systemctl stop qemu-autostart.service 2>/dev/null || true
    sudo systemctl disable qemu-autostart.service 2>/dev/null || true
    safe_rm_f_sudo /etc/systemd/system/qemu-autostart.service 2>/dev/null || sudo rm -f /etc/systemd/system/qemu-autostart.service
    sudo systemctl daemon-reload
    
    print_success "${MESSAGES[uninstall_success]}"
}

show_status() {
    print_info "${MESSAGES[status]}"
    
    if [ -f /etc/systemd/system/qemu-autostart.service ]; then
        sudo systemctl status qemu-autostart.service --no-pager || true
    else
        print_warning "${MESSAGES[not_installed]}"
    fi
}

show_help() {
    echo "Usage: $0 [--install|--uninstall|--status] [--lang en|ru]"
    echo ""
    echo "Options:"
    echo "  --install     Install autostart service"
    echo "  --uninstall   Uninstall autostart service"
    echo "  --status      Show service status"
    echo "  --lang        Set language (en or ru)"
    echo ""
}

main() {
    local action=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lang)
                set_language "$2"
                shift 2
                ;;
            --install)
                action="install"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -z "$LANG_CODE" || "$LANG_CODE" == "en" ]]; then
        detect_language
    fi
    
    load_messages
    
    case "$action" in
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        status)
            show_status
            ;;
        *)
            show_help
            ;;
    esac
}

main "$@"
