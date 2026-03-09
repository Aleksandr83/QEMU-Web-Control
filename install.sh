#!/bin/bash
set -e
set -E
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/safe-rm.sh
source "${SCRIPT_DIR}/scripts/safe-rm.sh"

for pattern in "install-*.log" "uninstall-*.log" "show_logs_*.log"; do
    for f in "${SCRIPT_DIR}"/${pattern}; do
        [ -f "$f" ] && safe_rm_f "$f" 2>/dev/null || true
    done
done

for f in /var/log/QemuControlService.log /var/log/QemuBootImagesControlService.log; do
    [ -f "$f" ] && safe_rm_f_sudo "$f" 2>/dev/null || true
done
for f in "${SCRIPT_DIR}"/storage/logs/*.log; do
    [ -f "$f" ] && safe_rm_f "$f" 2>/dev/null || true
done

LANG_CODE="en"
INSTALL_LOG="${SCRIPT_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

install_log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$INSTALL_LOG"
}

install_log_section() {
    echo "" >> "$INSTALL_LOG"
    echo "========== $1 ==========" >> "$INSTALL_LOG"
    install_log "$1"
}

INSTALL_ERRORS_FILE="${SCRIPT_DIR}/.install_errors_$$"
USE_APACHE_PROXY=false
DOCKER_SUDO=""

add_install_error() {
    install_log "INSTALL ERROR: $1"
    echo "$1" >> "$INSTALL_ERRORS_FILE" 2>/dev/null || true
}

log_fatal_error() {
    local msg="$1"
    print_error "$msg"
    install_log "ERROR: $msg"
    add_install_error "$msg"
    exit 1
}

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
    ["welcome"]="══════════════════════════════════════════════════════════════════════════"
    ["title"]="                      QEMU Web Control Installer                         "
    ["separator"]="══════════════════════════════════════════════════════════════════════════"
    ["bottom"]="══════════════════════════════════════════════════════════════════════════"
    ["checking_docker"]="Checking Docker installation..."
    ["docker_found"]="Docker is installed"
    ["docker_not_found"]="Docker is not installed"
    ["install_docker_prompt"]="Do you want to install Docker automatically? [y/n]:"
    ["installing_docker"]="Installing Docker..."
    ["docker_installed"]="Docker installed successfully"
    ["add_user_to_docker"]="Adding current user to docker group..."
    ["logout_required"]="Reboot is required for Docker group changes to apply correctly, then run ./install.sh again."
    ["logout_now_prompt"]="Reboot now? [y/n]:"
    ["run_install_after_login"]="Please reboot the system, then run ./install.sh again to continue installation."
    ["logging_out"]="Rebooting in 3 seconds..."
    ["logout_manual"]="Automatic reboot failed. Reboot manually, then run ./install.sh again."
    ["checking_apache"]="Checking Apache2 installation..."
    ["apache_found"]="Apache2 is installed"
    ["apache_proxy_prompt"]="Do you want to configure Apache2 as reverse proxy? [y/n]:"
    ["apache_proxy_port"]="Enter Apache2 proxy port (default 80):"
    ["apache_server_name"]="Enter ServerName (e.g. qemu-control.local)"
    ["apache_server_alias"]="Enter ServerAlias (comma-separated, or empty for none)"
    ["configuring_apache"]="Configuring Apache2 reverse proxy..."
    ["apache_configured"]="Apache2 configured successfully"
    ["apache_enable_modules"]="Enabling Apache2 modules..."
    ["apache_restart"]="Restarting Apache2..."
    ["firewall_configuring"]="Configuring firewall rules for Apache..."
    ["firewall_no_ufw"]="UFW not found, skipping firewall configuration"
    ["firewall_ufw_inactive"]="UFW is inactive, skipping firewall rule changes"
    ["firewall_iface_prompt"]="Select network interface for opening Apache ports:"
    ["firewall_iface_all"]="all interfaces"
    ["firewall_rules_applied"]="Firewall rules applied for Apache ports"
    ["firewall_rules_details"]="Applied firewall rules:"
    ["firewall_direct_prompt"]="Do you want to configure UFW rules for direct web access ports? [y/n]:"
    ["firewall_direct_configuring"]="Configuring firewall rules for direct web access..."
    ["vnc_console_iface_prompt"]="Select interface for VNC console WebSocket (host clients will use to connect):"
    ["vnc_console_localhost"]="127.0.0.1 (localhost, port forward from host)"
    ["firewall_direct_rules_applied"]="Firewall rules applied for web access ports"
    ["checking_env"]="Checking environment configuration..."
    ["creating_env"]="Creating .env file from .env.example..."
    ["env_created"]="Environment file created"
    ["db_choice"]="Choose database configuration:"
    ["db_docker"]="[1] Docker MariaDB (isolated)"
    ["db_external"]="[2] External MariaDB/MySQL (existing)"
    ["enter_choice"]="Enter your choice [1-2]:"
    ["db_host"]="Enter database host"
    ["db_port"]="Enter database port"
    ["db_name"]="Enter database name"
    ["db_user"]="Enter database username"
    ["db_pass"]="Enter database password"
    ["db_root_pass"]="Enter database root password"
    ["testing_connection"]="Testing database connection..."
    ["connection_success"]="Database connection successful"
    ["connection_failed"]="Database connection failed"
    ["creating_database"]="Creating database..."
    ["database_created"]="Database created successfully"
    ["database_exists"]="Database already exists"
    ["grant_privileges"]="Granting privileges..."
    ["privileges_granted"]="Privileges granted successfully"
    ["generating_ssl"]="Generating SSL certificates..."
    ["ssl_generated"]="SSL certificates generated"
    ["fixing_permissions"]="Fixing permissions..."
    ["permissions_fixed"]="Permissions fixed"
    ["building_containers"]="Building Docker containers..."
    ["starting_containers"]="Starting containers..."
    ["installing_dependencies"]="Installing Composer dependencies..."
    ["generating_key"]="Generating application key..."
    ["creating_storage_link"]="Creating storage link..."
    ["running_migrations"]="Running database migrations..."
    ["seeding_database"]="Seeding database..."
    ["installing_npm"]="Installing NPM dependencies..."
    ["building_assets"]="Building frontend assets..."
    ["installation_complete"]="Installation completed successfully!"
    ["installation_failed"]="Installation completed with errors"
    ["installation_log_success"]="Installation completed successfully (no errors)"
    ["installation_log_failed"]="Installation completed with errors"
    ["errors_list"]="Errors:"
    ["access_info"]="Access information:"
    ["http_url"]="HTTP:  http://localhost:"
    ["https_url"]="HTTPS: https://localhost:"
    ["admin_credentials"]="Administrator credentials:"
    ["admin_email"]="Login:    admin"
    ["admin_password"]="Password: admin"
    ["error"]="Error:"
    ["apache_nginx_conflict"]="Apache (80/443) + Docker nginx conflict detected"
    ["apache_nginx_fixing"]="Applying fix: switching to bridge mode (APP_PORT/APP_SSL_PORT)"
    ["checking_packages"]="Checking required APT packages..."
    ["installing_missing_packages"]="Installing missing APT packages..."
    ["missing_packages_after_install"]="Some required packages are still missing"
    ["required_packages_table_header"]="Package                          Status"
    ["qemu_arch_select"]="Select guest architectures to support (comma-separated numbers):"
    ["qemu_arch_available"]="Available QEMU guest architectures:"
    ["qemu_arch_default"]="Default"
    ["qemu_arch_none"]="No architecture packages available via apt-cache search",
    ["checking_sudo"]="Checking sudo privileges...",
    ["sudo_required"]="Sudo privileges are required. Run as a sudo-enabled user or as root.",
    ["sudo_no_tty_hint"]="No TTY. Run: sudo ./install.sh",
    ["boot_media_hint"]="Important: C++ service must run on host (e.g. QemuBootImagesControlService). For Docker set BOOT_MEDIA_SERVICE_URL=http://host.docker.internal:50052 (or http://172.17.0.1:50052)"
    ["db_firewall_prompt"]="Do you want to configure UFW rules for database port 3306? [y/n]:"
    ["db_firewall_configuring"]="Configuring firewall rules for database port 3306..."
    ["db_firewall_local"]="DB is on localhost with host network mode — firewall rules for 3306 are not required"
    ["db_firewall_docker"]="DB is a Docker container (db) — port 3306 is internal, no firewall rules needed"
    ["db_firewall_iface_prompt"]="Select network interface to allow access to port 3306:"
    ["db_firewall_rules_applied"]="Firewall rules for port 3306 applied"
    ["db_firewall_skipped"]="Firewall rules for DB port 3306 skipped"
    ["apache_port_conflict_detected"]="Apache2 is running on ports 80/443 — conflict with nginx container"
    ["apache_port_conflict_fixing"]="Switching nginx to alternative ports automatically..."
    ["apache_port_conflict_fixed"]="Nginx ports updated to avoid Apache2 conflict"
)

declare -A MESSAGES_RU=(
    ["welcome"]="══════════════════════════════════════════════════════════════════════════"
    ["title"]="                   Установщик QEMU Web Control                           "
    ["separator"]="══════════════════════════════════════════════════════════════════════════"
    ["bottom"]="══════════════════════════════════════════════════════════════════════════"
    ["checking_docker"]="Проверка установки Docker..."
    ["docker_found"]="Docker установлен"
    ["docker_not_found"]="Docker не установлен"
    ["install_docker_prompt"]="Хотите установить Docker автоматически? [y/n]:"
    ["installing_docker"]="Установка Docker..."
    ["docker_installed"]="Docker успешно установлен"
    ["add_user_to_docker"]="Добавление текущего пользователя в группу docker..."
    ["logout_required"]="Требуется перезагрузка, чтобы корректно применились изменения группы docker, затем снова запустите ./install.sh"
    ["logout_now_prompt"]="Перезагрузить систему сейчас? [y/n]:"
    ["run_install_after_login"]="Перезагрузите систему и снова запустите ./install.sh для продолжения установки."
    ["logging_out"]="Перезагрузка через 3 секунды..."
    ["logout_manual"]="Автоматическая перезагрузка недоступна. Перезагрузите систему вручную и снова запустите ./install.sh"
    ["checking_apache"]="Проверка установки Apache2..."
    ["apache_found"]="Apache2 установлен"
    ["apache_proxy_prompt"]="Настроить Apache2 как reverse proxy? [y/n]:"
    ["apache_proxy_port"]="Введите порт Apache2 proxy (по умолчанию 80):"
    ["apache_server_name"]="Введите ServerName (например qemu-control.local)"
    ["apache_server_alias"]="Введите ServerAlias (через запятую, или пусто)"
    ["configuring_apache"]="Настройка Apache2 reverse proxy..."
    ["apache_configured"]="Apache2 успешно настроен"
    ["apache_enable_modules"]="Включение модулей Apache2..."
    ["apache_restart"]="Перезапуск Apache2..."
    ["firewall_configuring"]="Настройка правил firewall для Apache..."
    ["firewall_no_ufw"]="UFW не найден, пропускаем настройку firewall"
    ["firewall_ufw_inactive"]="UFW неактивен, изменение правил не требуется"
    ["firewall_iface_prompt"]="Выберите сетевой интерфейс для открытия портов Apache:"
    ["firewall_iface_all"]="все интерфейсы"
    ["firewall_rules_applied"]="Правила firewall для портов Apache применены"
    ["firewall_rules_details"]="Применены правила firewall:"
    ["firewall_direct_prompt"]="Настроить правила UFW для портов прямого доступа к сайту? [y/n]:"
    ["firewall_direct_configuring"]="Настройка правил firewall для прямого доступа к сайту..."
    ["vnc_console_iface_prompt"]="Выберите интерфейс для VNC консоли (адрес для подключения клиентов):"
    ["vnc_console_localhost"]="127.0.0.1 (localhost, проброс портов с хоста)"
    ["firewall_direct_rules_applied"]="Правила firewall для портов сайта применены"
    ["checking_env"]="Проверка конфигурации окружения..."
    ["creating_env"]="Создание файла .env из .env.example..."
    ["env_created"]="Файл окружения создан"
    ["db_choice"]="Выберите конфигурацию базы данных:"
    ["db_docker"]="[1] Docker MariaDB (изолированная)"
    ["db_external"]="[2] Внешняя MariaDB/MySQL (существующая)"
    ["enter_choice"]="Введите ваш выбор [1-2]:"
    ["db_host"]="Введите хост базы данных"
    ["db_port"]="Введите порт базы данных"
    ["db_name"]="Введите имя базы данных"
    ["db_user"]="Введите имя пользователя БД"
    ["db_pass"]="Введите пароль БД"
    ["db_root_pass"]="Введите root пароль БД"
    ["testing_connection"]="Проверка подключения к базе данных..."
    ["connection_success"]="Подключение к базе данных успешно"
    ["connection_failed"]="Не удалось подключиться к базе данных"
    ["creating_database"]="Создание базы данных..."
    ["database_created"]="База данных успешно создана"
    ["database_exists"]="База данных уже существует"
    ["grant_privileges"]="Назначение привилегий..."
    ["privileges_granted"]="Привилегии успешно назначены"
    ["generating_ssl"]="Генерация SSL сертификатов..."
    ["ssl_generated"]="SSL сертификаты сгенерированы"
    ["fixing_permissions"]="Исправление прав доступа..."
    ["permissions_fixed"]="Права доступа исправлены"
    ["building_containers"]="Сборка Docker контейнеров..."
    ["starting_containers"]="Запуск контейнеров..."
    ["installing_dependencies"]="Установка зависимостей Composer..."
    ["generating_key"]="Генерация ключа приложения..."
    ["creating_storage_link"]="Создание ссылки на storage..."
    ["running_migrations"]="Выполнение миграций базы данных..."
    ["seeding_database"]="Заполнение базы данных..."
    ["installing_npm"]="Установка зависимостей NPM..."
    ["building_assets"]="Сборка frontend ресурсов..."
    ["installation_complete"]="Установка успешно завершена!"
    ["installation_failed"]="Установка завершена с ошибками"
    ["installation_log_success"]="Установка прошла без ошибок"
    ["installation_log_failed"]="Установка завершилась с ошибками"
    ["errors_list"]="Ошибки:"
    ["access_info"]="Информация для доступа:"
    ["http_url"]="HTTP:  http://localhost:"
    ["https_url"]="HTTPS: https://localhost:"
    ["admin_credentials"]="Учетные данные администратора:"
    ["admin_email"]="Логин:    admin"
    ["admin_password"]="Пароль:   admin"
    ["error"]="Ошибка:"
    ["apache_nginx_conflict"]="Обнаружен конфликт Apache (80/443) + Docker nginx"
    ["apache_nginx_fixing"]="Применение исправления: переключение на bridge mode (APP_PORT/APP_SSL_PORT)"
    ["checking_packages"]="Проверка обязательных APT-пакетов..."
    ["installing_missing_packages"]="Установка недостающих APT-пакетов..."
    ["missing_packages_after_install"]="Часть обязательных пакетов все еще отсутствует"
    ["required_packages_table_header"]="Пакет                            Статус"
    ["qemu_arch_select"]="Выберите поддерживаемые архитектуры гостей (номера через запятую):"
    ["qemu_arch_available"]="Доступные архитектуры гостей QEMU:"
    ["qemu_arch_default"]="По умолчанию"
    ["qemu_arch_none"]="Не найдены пакеты архитектур через apt-cache search",
    ["checking_sudo"]="Проверка sudo-привилегий...",
    ["sudo_required"]="Требуются sudo-привилегии. Запустите от пользователя с sudo или от root.",
    ["sudo_no_tty_hint"]="Нет TTY. Запустите: sudo ./install.sh",
    ["boot_media_hint"]="Важно: C++ сервис должен быть запущен на хосте (например, QemuBootImagesControlService). Для Docker укажите BOOT_MEDIA_SERVICE_URL=http://host.docker.internal:50052 (или http://172.17.0.1:50052)"
    ["db_firewall_prompt"]="Настроить правила UFW для порта базы данных 3306? [y/n]:"
    ["db_firewall_configuring"]="Настройка правил firewall для порта БД 3306..."
    ["db_firewall_local"]="БД на localhost с host network mode — правила firewall для 3306 не требуются"
    ["db_firewall_docker"]="БД в Docker-контейнере (db) — порт 3306 внутренний, правила firewall не нужны"
    ["db_firewall_iface_prompt"]="Выберите сетевой интерфейс для открытия порта 3306:"
    ["db_firewall_rules_applied"]="Правила firewall для порта 3306 применены"
    ["db_firewall_skipped"]="Настройка firewall для порта 3306 пропущена"
    ["apache_port_conflict_detected"]="Apache2 запущен на портах 80/443 — конфликт с nginx-контейнером"
    ["apache_port_conflict_fixing"]="Автоматически переключаю nginx на альтернативные порты..."
    ["apache_port_conflict_fixed"]="Порты nginx обновлены для избежания конфликта с Apache2"
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

resolve_primary_ip() {
    local ip=""

    ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
        echo "$ip"
        return
    fi

    ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./ && $i != "127.0.0.1"){print $i; exit}}')
    if [ -n "$ip" ]; then
        echo "$ip"
        return
    fi

    echo ""
}

check_sudo_privileges() {
    print_info "${MESSAGES[checking_sudo]}"

    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        install_log "Running as root, sudo check skipped"
        return 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        log_fatal_error "${MESSAGES[sudo_required]}"
    fi

    if sudo -n true 2>/dev/null; then
        install_log "Sudo privileges confirmed (passwordless)"
        return 0
    fi

    if [ -t 0 ] && [ -t 1 ]; then
        if ! sudo -v; then
            log_fatal_error "${MESSAGES[sudo_required]}"
        fi
        install_log "Sudo privileges confirmed"
        return 0
    fi

    log_fatal_error "${MESSAGES[sudo_required]} ${MESSAGES[sudo_no_tty_hint]}"
}

format_line() {
    local text="$1"
    local max_width=70
    
    local text_len
    if command -v python3 >/dev/null 2>&1; then
        text_len=$(python3 -c "import sys; print(len(sys.argv[1]))" "$text" 2>/dev/null)
    else
        text_len=$(printf '%s' "$text" | wc -m | tr -d '[:space:]')
    fi
    
    if [ -z "$text_len" ] || [ "$text_len" -eq 0 ]; then
        text_len=${#text}
    fi
    
    local padding_len=$((max_width - text_len))
    if [ "$padding_len" -lt 0 ]; then
        padding_len=0
    fi
    local padding=$(printf "%${padding_len}s" "")
    
    printf "  %s%s  \n" "$text" "$padding"
}

print_header() {
    echo ""
    echo "${MESSAGES[welcome]}"
    format_line "${MESSAGES[title]}"
    echo "${MESSAGES[separator]}"
}

print_footer() {
    echo "${MESSAGES[bottom]}"
    echo ""
}

fix_permissions() {
    print_info "${MESSAGES[fixing_permissions]}"
    
    mkdir -p vendor node_modules storage bootstrap/cache public \
             storage/logs storage/framework/cache storage/framework/sessions storage/framework/views \
             storage/app/public docker/nginx/ssl
    
    sudo chown -R 1000:1000 vendor node_modules storage bootstrap/cache public docker/nginx/ssl 2>/dev/null || true
    
    for file in .env composer.json composer.lock package.json package-lock.json; do
        [ -f "$file" ] && sudo chown 1000:1000 "$file" 2>/dev/null || true
    done
    
    chmod -R 775 storage bootstrap/cache public 2>/dev/null || true
    chmod -R 755 vendor node_modules 2>/dev/null || true
    
    print_success "${MESSAGES[permissions_fixed]}"
}

check_architecture() {
    local arch=$(uname -m)
    
    if [[ "$arch" == "riscv64" ]]; then
        echo ""
        print_warning "⚠ RISC-V architecture detected!"
        if [[ "$LANG_CODE" == "ru" ]]; then
            echo "  Обнаружена архитектура RISC-V ($arch)"
            echo "  Установка может занять 20-30 минут"
            echo "  См. docs/RU/RISCV.RU.md для подробностей"
        else
            echo "  RISC-V architecture detected ($arch)"
            echo "  Installation may take 20-30 minutes"
            echo "  See docs/EN/RISCV.EN.md for details"
        fi
        echo ""
        sleep 3
    fi
}

declare -a SELECTED_QEMU_ARCHES=()
declare -a SELECTED_QEMU_PACKAGES=()
DEFAULT_QEMU_ARCH="x86_64"

qemu_binary_for_arch() {
    case "$1" in
        x86_64) echo "/usr/bin/qemu-system-x86_64" ;;
        i386) echo "/usr/bin/qemu-system-i386" ;;
        arm) echo "/usr/bin/qemu-system-arm" ;;
        aarch64) echo "/usr/bin/qemu-system-aarch64" ;;
        riscv64) echo "/usr/bin/qemu-system-riscv64" ;;
        mips) echo "/usr/bin/qemu-system-mips" ;;
        ppc64) echo "/usr/bin/qemu-system-ppc64" ;;
        sparc) echo "/usr/bin/qemu-system-sparc64" ;;
        *) echo "/usr/bin/qemu-system-x86_64" ;;
    esac
}

ensure_qemu_targets_in_env() {
    [ ! -f .env ] && return 0
    [ ${#SELECTED_QEMU_ARCHES[@]} -eq 0 ] && return 0

    local target_arches default_bin qemu_apt_packages
    target_arches=$(IFS=,; echo "${SELECTED_QEMU_ARCHES[*]}")
    default_bin=$(qemu_binary_for_arch "$DEFAULT_QEMU_ARCH")
    qemu_apt_packages="qemu-utils"

    if grep -qE '^QEMU_TARGET_ARCHES=' .env; then
        sed -i "s|^QEMU_TARGET_ARCHES=.*|QEMU_TARGET_ARCHES=${target_arches}|" .env
    else
        echo "QEMU_TARGET_ARCHES=${target_arches}" >> .env
    fi

    if grep -qE '^QEMU_BIN_PATH=' .env; then
        sed -i "s|^QEMU_BIN_PATH=.*|QEMU_BIN_PATH=${default_bin}|" .env
    else
        echo "QEMU_BIN_PATH=${default_bin}" >> .env
    fi

    if grep -qE '^QEMU_APT_PACKAGES=' .env; then
        sed -i "s|^QEMU_APT_PACKAGES=.*|QEMU_APT_PACKAGES=\"${qemu_apt_packages}\"|" .env
    else
        echo "QEMU_APT_PACKAGES=\"${qemu_apt_packages}\"" >> .env
    fi

    install_log "QEMU target architectures: ${target_arches}; default binary: ${default_bin}; container packages: ${qemu_apt_packages}"
}

select_qemu_architectures() {
    local apt_cache_out
    apt_cache_out=$(apt-cache search '^qemu-system-' 2>/dev/null || true)
    if [ -z "$apt_cache_out" ]; then
        sudo apt-get update >/dev/null 2>&1 || true
        apt_cache_out=$(apt-cache search '^qemu-system-' 2>/dev/null || true)
    fi
    if [ -z "$apt_cache_out" ]; then
        log_fatal_error "${MESSAGES[qemu_arch_none]}"
    fi

    local -a available_packages=()
    mapfile -t available_packages < <(printf '%s\n' "$apt_cache_out" | awk '{print $1}' | sort -u)

    local -a option_arches=()
    local -a option_packages=()
    local -a option_labels=()

    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-x86'; then
        option_arches+=("x86_64" "i386")
        option_packages+=("qemu-system-x86" "qemu-system-x86")
        option_labels+=("x86_64" "i386")
    fi
    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-arm'; then
        option_arches+=("arm" "aarch64")
        option_packages+=("qemu-system-arm" "qemu-system-arm")
        option_labels+=("arm" "aarch64")
    fi
    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-mips'; then
        option_arches+=("mips")
        option_packages+=("qemu-system-mips")
        option_labels+=("mips")
    fi
    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-ppc'; then
        option_arches+=("ppc64")
        option_packages+=("qemu-system-ppc")
        option_labels+=("ppc64")
    fi
    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-sparc'; then
        option_arches+=("sparc")
        option_packages+=("qemu-system-sparc")
        option_labels+=("sparc")
    fi
    if printf '%s\n' "${available_packages[@]}" | grep -qx 'qemu-system-misc'; then
        option_arches+=("riscv64")
        option_packages+=("qemu-system-misc")
        option_labels+=("riscv64")
    fi

    if [ ${#option_arches[@]} -eq 0 ]; then
        log_fatal_error "${MESSAGES[qemu_arch_none]}"
    fi

    local host_arch selected_default_idx=1 idx
    host_arch=$(uname -m)
    for idx in "${!option_arches[@]}"; do
        if [ "${option_arches[$idx]}" = "$host_arch" ]; then
            selected_default_idx=$((idx + 1))
            break
        fi
    done

    echo ""
    echo "${MESSAGES[qemu_arch_available]}"
    for idx in "${!option_arches[@]}"; do
        local marker=""
        if [ $((idx + 1)) -eq "$selected_default_idx" ]; then
            marker=" (${MESSAGES[qemu_arch_default]})"
        fi
        echo "  $((idx + 1))) ${option_labels[$idx]} [${option_packages[$idx]}]${marker}"
    done
    echo ""

    local selected_raw
    read -p "${MESSAGES[qemu_arch_select]} [${selected_default_idx}]: " selected_raw
    selected_raw=${selected_raw:-$selected_default_idx}
    selected_raw=$(echo "$selected_raw" | tr ';' ',' | tr -d ' ')

    local -a selected_idxs=()
    IFS=',' read -r -a selected_idxs <<< "$selected_raw"

    local -a selected_arches=()
    local -a selected_packages=()
    local sel
    for sel in "${selected_idxs[@]}"; do
        [[ "$sel" =~ ^[0-9]+$ ]] || continue
        if [ "$sel" -lt 1 ] || [ "$sel" -gt "${#option_arches[@]}" ]; then
            continue
        fi
        local arr_idx=$((sel - 1))
        selected_arches+=("${option_arches[$arr_idx]}")
        selected_packages+=("${option_packages[$arr_idx]}")
    done

    if [ ${#selected_arches[@]} -eq 0 ]; then
        selected_arches+=("${option_arches[$((selected_default_idx - 1))]}")
        selected_packages+=("${option_packages[$((selected_default_idx - 1))]}")
    fi

    SELECTED_QEMU_ARCHES=()
    SELECTED_QEMU_PACKAGES=()
    local seen_arches="" seen_pkgs="" item
    for item in "${selected_arches[@]}"; do
        if [[ ",$seen_arches," != *",$item,"* ]]; then
            SELECTED_QEMU_ARCHES+=("$item")
            seen_arches="${seen_arches},${item}"
        fi
    done
    for item in "${selected_packages[@]}"; do
        if [[ ",$seen_pkgs," != *",$item,"* ]]; then
            SELECTED_QEMU_PACKAGES+=("$item")
            seen_pkgs="${seen_pkgs},${item}"
        fi
    done

    DEFAULT_QEMU_ARCH="${SELECTED_QEMU_ARCHES[0]}"
    install_log "Selected QEMU arches: ${SELECTED_QEMU_ARCHES[*]}"
    install_log "Selected QEMU packages: ${SELECTED_QEMU_PACKAGES[*]}"
}

check_required_apt_packages() {
    print_info "${MESSAGES[checking_packages]}"
    install_log_section "APT package check"
    select_qemu_architectures

    local required_packages=(
        curl
        wget
        sed
        ca-certificates
        gnupg
        openssl
        unzip
        zip
        lsof
        net-tools
        git
        build-essential
        cmake
        pkg-config
        libgrpc++-dev
        libprotobuf-dev
        protobuf-compiler-grpc
        libpng-dev
        libonig-dev
        libxml2-dev
        libicu-dev
        php
        php-cli
        php-mbstring
        php-xml
        php-curl
        php-zip
        php-intl
        php-sqlite3
        composer
        nginx
        nodejs
        npm
        mariadb-client
        qemu-utils
    )

    local qemu_pkg
    for qemu_pkg in "${SELECTED_QEMU_PACKAGES[@]}"; do
        required_packages+=("$qemu_pkg")
    done

    local missing_packages=()
    local pkg
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_info "${MESSAGES[installing_missing_packages]}"
        install_log "Missing packages before install: ${missing_packages[*]}"
        sudo apt-get update
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_packages[@]}"; then
            install_log "apt-get install returned non-zero exit code"
        fi
    fi

    local still_missing=()
    local table_line
    echo ""
    echo "" >> "$INSTALL_LOG"
    echo "${MESSAGES[required_packages_table_header]}"
    echo "${MESSAGES[required_packages_table_header]}" >> "$INSTALL_LOG"
    echo "-----------------------------------------------"
    echo "-----------------------------------------------" >> "$INSTALL_LOG"
    for pkg in "${required_packages[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            table_line=$(printf "%-32s %s" "$pkg" "OK")
            echo "$table_line"
            echo "$table_line" >> "$INSTALL_LOG"
        else
            table_line=$(printf "%-32s %s" "$pkg" "No")
            echo "$table_line"
            echo "$table_line" >> "$INSTALL_LOG"
            still_missing+=("$pkg")
        fi
    done
    echo ""
    echo "" >> "$INSTALL_LOG"

    if [ ${#still_missing[@]} -gt 0 ]; then
        install_log "Missing packages after install: ${still_missing[*]}"
        log_fatal_error "${MESSAGES[missing_packages_after_install]}: ${still_missing[*]}"
    fi
}

check_apache() {
    print_info "${MESSAGES[checking_apache]}"
    
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        print_success "${MESSAGES[apache_found]}"
        echo ""
        read -p "${MESSAGES[apache_proxy_prompt]} " configure_apache
        
        if [[ "$configure_apache" =~ ^[Yy]$ ]]; then
            USE_APACHE_PROXY=true
            configure_apache_proxy
        fi
    fi
}

configure_apache_firewall() {
    local apache_port="$1"
    local apache_ssl_port="$2"

    print_info "${MESSAGES[firewall_configuring]}"
    install_log_section "Apache firewall configuration"

    if ! command -v ufw >/dev/null 2>&1; then
        print_warning "${MESSAGES[firewall_no_ufw]}"
        install_log "UFW not found, firewall step skipped"
        return 0
    fi

    if ! sudo ufw status 2>/dev/null | grep -qi "Status: active"; then
        print_info "${MESSAGES[firewall_ufw_inactive]}"
        install_log "UFW inactive, firewall step skipped"
        return 0
    fi

    local interfaces=()
    mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -Ev '^(lo|docker.*|br-.*|veth.*)$')

    echo ""
    echo "${MESSAGES[firewall_iface_prompt]}"
    echo "  0) ${MESSAGES[firewall_iface_all]}"
    local i=1
    local iface
    for iface in "${interfaces[@]}"; do
        local ipv4_info ipv6_info ip_mode
        ipv4_info=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd',' -)
        ipv6_info=$(ip -6 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd',' -)
        [ -z "$ipv4_info" ] && ipv4_info="-"
        [ -z "$ipv6_info" ] && ipv6_info="-"

        if ip -4 -o addr show dev "$iface" 2>/dev/null | grep -q " dynamic " || ip -6 -o addr show dev "$iface" 2>/dev/null | grep -q " dynamic "; then
            ip_mode="DHCP"
        else
            ip_mode="static"
        fi

        echo "  $i) $iface [$ip_mode, IPv4: $ipv4_info, IPv6: $ipv6_info]"
        i=$((i + 1))
    done
    echo ""

    local selected_idx
    read -p "Select [0]: " selected_idx
    selected_idx=${selected_idx:-0}

    local selected_iface="all"
    if [[ "$selected_idx" =~ ^[0-9]+$ ]] && [ "$selected_idx" -gt 0 ] && [ "$selected_idx" -le "${#interfaces[@]}" ]; then
        selected_iface="${interfaces[$((selected_idx - 1))]}"
    fi

    local applied_rule
    if [ "$selected_iface" = "all" ]; then
        sudo ufw allow "${apache_port}/tcp" >/dev/null 2>&1 || true
        [ "$apache_ssl_port" != "$apache_port" ] && sudo ufw allow "${apache_ssl_port}/tcp" >/dev/null 2>&1 || true
        install_log "UFW rules: allow ${apache_port}/tcp and ${apache_ssl_port}/tcp on all interfaces"
        applied_rule="interface=all ports=${apache_port},${apache_ssl_port}/tcp"
    else
        sudo ufw allow in on "$selected_iface" to any port "$apache_port" proto tcp >/dev/null 2>&1 || true
        [ "$apache_ssl_port" != "$apache_port" ] && sudo ufw allow in on "$selected_iface" to any port "$apache_ssl_port" proto tcp >/dev/null 2>&1 || true
        install_log "UFW rules: allow ports ${apache_port},${apache_ssl_port} on interface $selected_iface"
        applied_rule="interface=${selected_iface} ports=${apache_port},${apache_ssl_port}/tcp"
    fi

    print_success "${MESSAGES[firewall_rules_applied]}"
    print_info "${MESSAGES[firewall_rules_details]} ${applied_rule}"
    install_log "${MESSAGES[firewall_rules_details]} ${applied_rule}"
}

configure_db_firewall() {
    local db_host db_port
    db_host=$(grep -E '^DB_HOST=' .env 2>/dev/null | cut -d '=' -f2)
    db_port=$(grep -E '^DB_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    db_host=${db_host:-127.0.0.1}
    db_port=${db_port:-3306}

    if [ "$db_host" = "db" ]; then
        install_log "DB_HOST=db — DB firewall skipped (Docker internal)"
        print_info "${MESSAGES[db_firewall_docker]}"
        return 0
    fi

    if ! command -v ufw >/dev/null 2>&1; then
        install_log "UFW not found, DB firewall skipped"
        return 0
    fi

    if ! sudo ufw status 2>/dev/null | grep -qi "Status: active"; then
        install_log "UFW inactive, DB firewall skipped"
        return 0
    fi

    local uses_host_network="no"
    grep -q "network_mode.*host" docker-compose.yml 2>/dev/null && uses_host_network="yes"

    if { [ "$db_host" = "localhost" ] || [ "$db_host" = "127.0.0.1" ]; } && [ "$uses_host_network" = "yes" ]; then
        install_log "DB_HOST=$db_host with host network — DB firewall skipped"
        print_info "${MESSAGES[db_firewall_local]}"
        return 0
    fi

    print_info "${MESSAGES[db_firewall_configuring]}"
    install_log_section "DB firewall configuration (port $db_port)"

    if [ "$db_host" = "localhost" ] || [ "$db_host" = "127.0.0.1" ]; then
        local docker_subnet
        docker_subnet=$(docker network inspect qemu_qemu_network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null | head -1) || true
        if [ -z "$docker_subnet" ]; then
            docker_subnet="172.16.0.0/12"
            install_log "DB on localhost, qemu_qemu_network not found yet — using broad Docker range $docker_subnet"
        fi
        install_log "DB on localhost, Docker bridge — adding UFW rule: from $docker_subnet to port $db_port"
        sudo ufw allow from "$docker_subnet" to any port "$db_port" proto tcp >/dev/null 2>&1 || true
        sudo ufw allow from "172.16.0.0/12" to any port "$db_port" proto tcp >/dev/null 2>&1 || true
        sudo ufw reload >/dev/null 2>&1 || true
        print_success "${MESSAGES[db_firewall_rules_applied]}"
        print_info "${MESSAGES[firewall_rules_details]} from=$docker_subnet port=${db_port}/tcp"
        install_log "${MESSAGES[firewall_rules_details]} from=$docker_subnet port=${db_port}/tcp"
        return 0
    fi

    echo ""
    read -p "${MESSAGES[db_firewall_prompt]} " configure_db_fw
    if [[ ! "$configure_db_fw" =~ ^[Yy]$ ]]; then
        install_log "DB firewall configuration skipped by user"
        print_info "${MESSAGES[db_firewall_skipped]}"
        return 0
    fi

    local interfaces=()
    mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -Ev '^(lo|docker.*|br-.*|veth.*)$')

    echo ""
    echo "${MESSAGES[db_firewall_iface_prompt]}"
    echo "  0) ${MESSAGES[firewall_iface_all]}"
    local i=1
    local iface
    for iface in "${interfaces[@]}"; do
        local ipv4_info
        ipv4_info=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd',' -)
        [ -z "$ipv4_info" ] && ipv4_info="-"
        echo "  $i) $iface [IPv4: $ipv4_info]"
        i=$((i + 1))
    done
    echo ""

    local selected_idx
    read -p "Select [0]: " selected_idx
    selected_idx=${selected_idx:-0}

    local selected_iface="all"
    if [[ "$selected_idx" =~ ^[0-9]+$ ]] && [ "$selected_idx" -gt 0 ] && [ "$selected_idx" -le "${#interfaces[@]}" ]; then
        selected_iface="${interfaces[$((selected_idx - 1))]}"
    fi

    local applied_rule
    if [ "$selected_iface" = "all" ]; then
        sudo ufw allow "${db_port}/tcp" >/dev/null 2>&1 || true
        install_log "UFW rule: allow ${db_port}/tcp on all interfaces"
        applied_rule="interface=all port=${db_port}/tcp"
    else
        sudo ufw allow in on "$selected_iface" to any port "$db_port" proto tcp >/dev/null 2>&1 || true
        install_log "UFW rule: allow port $db_port on interface $selected_iface"
        applied_rule="interface=${selected_iface} port=${db_port}/tcp"
    fi

    sudo ufw reload >/dev/null 2>&1 || true

    print_success "${MESSAGES[db_firewall_rules_applied]}"
    print_info "${MESSAGES[firewall_rules_details]} ${applied_rule}"
    install_log "${MESSAGES[firewall_rules_details]} ${applied_rule}"
}

configure_direct_web_firewall() {
    if [ "$USE_APACHE_PROXY" = true ]; then
        install_log "Direct web firewall skipped: Apache proxy mode is enabled"
        return 0
    fi

    local app_port app_ssl_port
    app_port=$(grep -E '^APP_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    app_ssl_port=$(grep -E '^APP_SSL_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    app_port=${app_port:-8080}
    app_ssl_port=${app_ssl_port:-8443}

    echo ""
    read -p "${MESSAGES[firewall_direct_prompt]} " configure_direct_fw
    if [[ ! "$configure_direct_fw" =~ ^[Yy]$ ]]; then
        install_log "Direct web firewall configuration skipped by user"
        return 0
    fi

    print_info "${MESSAGES[firewall_direct_configuring]}"
    install_log_section "Direct web firewall configuration"

    if ! command -v ufw >/dev/null 2>&1; then
        print_warning "${MESSAGES[firewall_no_ufw]}"
        install_log "UFW not found, firewall step skipped"
        return 0
    fi

    if ! sudo ufw status 2>/dev/null | grep -qi "Status: active"; then
        print_info "${MESSAGES[firewall_ufw_inactive]}"
        install_log "UFW inactive, firewall step skipped"
        return 0
    fi

    local interfaces=()
    mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -Ev '^(lo|docker.*|br-.*|veth.*)$')

    echo ""
    echo "${MESSAGES[firewall_iface_prompt]}"
    echo "  0) ${MESSAGES[firewall_iface_all]}"
    local i=1
    local iface
    for iface in "${interfaces[@]}"; do
        local ipv4_info ipv6_info ip_mode
        ipv4_info=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd',' -)
        ipv6_info=$(ip -6 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | paste -sd',' -)
        [ -z "$ipv4_info" ] && ipv4_info="-"
        [ -z "$ipv6_info" ] && ipv6_info="-"

        if ip -4 -o addr show dev "$iface" 2>/dev/null | grep -q " dynamic " || ip -6 -o addr show dev "$iface" 2>/dev/null | grep -q " dynamic "; then
            ip_mode="DHCP"
        else
            ip_mode="static"
        fi

        echo "  $i) $iface [$ip_mode, IPv4: $ipv4_info, IPv6: $ipv6_info]"
        i=$((i + 1))
    done
    echo ""

    local selected_idx
    read -p "Select [0]: " selected_idx
    selected_idx=${selected_idx:-0}

    local selected_iface="all"
    if [[ "$selected_idx" =~ ^[0-9]+$ ]] && [ "$selected_idx" -gt 0 ] && [ "$selected_idx" -le "${#interfaces[@]}" ]; then
        selected_iface="${interfaces[$((selected_idx - 1))]}"
    fi

    local applied_rule
    if [ "$selected_iface" = "all" ]; then
        sudo ufw allow "${app_port}/tcp" >/dev/null 2>&1 || true
        [ "$app_ssl_port" != "$app_port" ] && sudo ufw allow "${app_ssl_port}/tcp" >/dev/null 2>&1 || true
        install_log "UFW rules: allow ${app_port}/tcp and ${app_ssl_port}/tcp on all interfaces"
        applied_rule="interface=all ports=${app_port},${app_ssl_port}/tcp"
    else
        sudo ufw allow in on "$selected_iface" to any port "$app_port" proto tcp >/dev/null 2>&1 || true
        [ "$app_ssl_port" != "$app_port" ] && sudo ufw allow in on "$selected_iface" to any port "$app_ssl_port" proto tcp >/dev/null 2>&1 || true
        install_log "UFW rules: allow ports ${app_port},${app_ssl_port} on interface $selected_iface"
        applied_rule="interface=${selected_iface} ports=${app_port},${app_ssl_port}/tcp"
    fi

    print_success "${MESSAGES[firewall_direct_rules_applied]}"
    print_info "${MESSAGES[firewall_rules_details]} ${applied_rule}"
    install_log "${MESSAGES[firewall_rules_details]} ${applied_rule}"
}

configure_apache_proxy() {
    print_info "${MESSAGES[configuring_apache]}"
    install_log_section "Apache proxy configuration"
    
    [ ! -f .env ] && print_error ".env not found" && return 1
    
    local app_port=$(grep APP_PORT .env | cut -d '=' -f2)
    local app_ssl_port=$(grep APP_SSL_PORT .env | cut -d '=' -f2)
    app_port=${app_port:-8080}
    app_ssl_port=${app_ssl_port:-8443}
    
    install_log "App ports: HTTP=$app_port, HTTPS=$app_ssl_port"
    
    check_port() {
        ss -tlnp 2>/dev/null | grep -q ":$1 " || netstat -tlnp 2>/dev/null | grep -q ":$1 "
    }
    
    port_used_by_apache() {
        local port=$1
        ss -tlnp 2>/dev/null | grep -E ":$port " | grep -qE "apache2|httpd" || \
        netstat -tlnp 2>/dev/null | grep -E ":$port " | grep -qE "apache2|httpd" || \
        lsof -i :$port 2>/dev/null | grep -qE "apache2|httpd"
    }
    
    local apache_port=80
    local apache_ssl_port=443
    
    if check_port 80; then
        if port_used_by_apache 80; then
            apache_port=80
            print_info "Port 80 used by Apache - adding VirtualHost to existing Apache"
        else
            print_warning "Port 80 is already in use by another process"
            local alt_port=8080
            while check_port $alt_port && [ $alt_port -lt 9000 ]; do
                alt_port=$((alt_port + 1))
            done
            echo ""
            read -p "Use alternative Apache port [$alt_port]: " apache_port
            apache_port=${apache_port:-$alt_port}
        fi
    else
        read -p "${MESSAGES[apache_proxy_port]} [80]: " input_port
        apache_port=${input_port:-80}
    fi
    
    if check_port 443; then
        if port_used_by_apache 443; then
            apache_ssl_port=443
            print_info "Port 443 used by Apache - adding VirtualHost to existing Apache"
        else
            print_warning "Port 443 is already in use by another process"
            local alt_ssl=8443
            while check_port $alt_ssl && [ $alt_ssl -lt 9000 ]; do
                alt_ssl=$((alt_ssl + 1))
            done
            read -p "Use alternative Apache SSL port [$alt_ssl]: " input_ssl
            apache_ssl_port=${input_ssl:-$alt_ssl}
        fi
    else
        apache_ssl_port=443
    fi
    
    read -p "${MESSAGES[apache_server_name]} [localhost]: " server_name
    server_name=${server_name:-localhost}
    
    read -p "${MESSAGES[apache_server_alias]} [qemu-control]: " server_alias
    server_alias=${server_alias:-qemu-control}
    
    local config_file="/etc/apache2/sites-available/qemu-control.conf"
    
    local alias_line=""
    [ -n "$server_alias" ] && alias_line="    ServerAlias ${server_alias}"
    
    local ssl_cert="${SCRIPT_DIR}/docker/nginx/ssl/server.crt"
    local ssl_key="${SCRIPT_DIR}/docker/nginx/ssl/server.key"
    
    {
        if [ "$apache_port" != "80" ]; then
            echo "Listen ${apache_port}"
        fi
        if [ "$apache_ssl_port" != "443" ] && [ -f "$ssl_cert" ]; then
            echo "Listen ${apache_ssl_port}"
        fi
        echo ""
        echo "<VirtualHost *:${apache_port}>"
        echo "    ServerName ${server_name}"
        [ -n "$alias_line" ] && echo "$alias_line"
        echo ""
        echo "    ProxyPreserveHost On"
        echo "    ProxyPass /vnc/ ws://localhost:${app_port}/vnc/"
        echo "    ProxyPassReverse /vnc/ ws://localhost:${app_port}/vnc/"
        echo "    ProxyPass / http://localhost:${app_port}/"
        echo "    ProxyPassReverse / http://localhost:${app_port}/"
        echo "    RequestHeader set X-Forwarded-Proto \"http\""
        echo "    RequestHeader set X-Forwarded-Port \"${apache_port}\""
        echo ""
        echo "    ErrorLog \${APACHE_LOG_DIR}/qemu-control-error.log"
        echo "    CustomLog \${APACHE_LOG_DIR}/qemu-control-access.log combined"
        echo "</VirtualHost>"
        
        if [ -f "$ssl_cert" ] && [ -f "$ssl_key" ]; then
            echo ""
            echo "<VirtualHost *:${apache_ssl_port}>"
            echo "    ServerName ${server_name}"
            [ -n "$alias_line" ] && echo "$alias_line"
            echo ""
            echo "    SSLEngine on"
            echo "    SSLCertificateFile ${ssl_cert}"
            echo "    SSLCertificateKeyFile ${ssl_key}"
            echo ""
            echo "    ProxyPreserveHost On"
            echo "    ProxyPass / https://localhost:${app_ssl_port}/"
            echo "    ProxyPassReverse / https://localhost:${app_ssl_port}/"
            echo "    SSLProxyEngine On"
            echo "    SSLProxyVerify none"
            echo "    SSLProxyCheckPeerCN off"
            echo "    SSLProxyCheckPeerName off"
            echo "    ProxyPass /vnc/ wss://localhost:${app_ssl_port}/vnc/"
            echo "    ProxyPassReverse /vnc/ wss://localhost:${app_ssl_port}/vnc/"
            echo "    RequestHeader set X-Forwarded-Proto \"https\""
            echo "    RequestHeader set X-Forwarded-Port \"${apache_ssl_port}\""
            echo ""
            echo "    ErrorLog \${APACHE_LOG_DIR}/qemu-control-ssl-error.log"
            echo "    CustomLog \${APACHE_LOG_DIR}/qemu-control-ssl-access.log combined"
            echo "</VirtualHost>"
        fi
    } | sudo tee "$config_file" > /dev/null
    
    if [ -f "$ssl_cert" ]; then
        sudo a2enmod ssl 2>/dev/null || true
    fi
    
    print_info "${MESSAGES[apache_enable_modules]}"
    sudo a2enmod proxy proxy_http proxy_wstunnel headers 2>/dev/null || true
    sudo a2ensite qemu-control.conf 2>/dev/null || true
    
    print_info "${MESSAGES[apache_restart]}"
    sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true
    configure_apache_firewall "$apache_port" "$apache_ssl_port"
    
    if [ "$apache_port" = "80" ]; then
        sed -i "s|APP_URL=.*|APP_URL=http://${server_name}|" .env
        install_log "Apache configured: ServerName=$server_name, Proxy->localhost:$app_port, APP_URL=http://${server_name}"
    else
        sed -i "s|APP_URL=.*|APP_URL=http://${server_name}:${apache_port}|" .env
        install_log "Apache configured: ServerName=$server_name, Proxy->localhost:$app_port, APP_URL=http://${server_name}:${apache_port}"
    fi
    print_info "Updating Laravel config..."
    local compose_cmd_apache="${DOCKER_SUDO}docker compose"
    ${DOCKER_SUDO}docker compose version &>/dev/null || compose_cmd_apache="${DOCKER_SUDO}docker-compose"
    $compose_cmd_apache exec -T app php artisan config:clear 2>/dev/null || true
    print_success "${MESSAGES[apache_configured]}"
    install_log "Apache configured: ServerName=$server_name, Proxy->localhost:$app_port"
    echo ""
}

check_docker() {
    print_info "${MESSAGES[checking_docker]}"
    
    local docker_found=false
    local compose_found=false
    
    # Проверяем docker
    if command -v docker &> /dev/null; then
        docker_found=true
    fi
    
    # Проверяем docker-compose (может быть как отдельная команда или плагин)
    if command -v docker-compose &> /dev/null; then
        compose_found=true
    elif docker compose version &> /dev/null; then
        compose_found=true
    fi
    
    if [ "$docker_found" = true ] && [ "$compose_found" = true ]; then
        print_success "${MESSAGES[docker_found]}"
        if ! docker ps -q &>/dev/null; then
            local err
            err=$(docker ps -q 2>&1) || true
            if echo "$err" | grep -qi "permission denied"; then
                DOCKER_SUDO="sudo "
                install_log "Docker socket permission denied in this session; using sudo for Docker commands"
            fi
        fi

        if ! ${DOCKER_SUDO}docker info &>/dev/null; then
            install_log "Docker daemon unavailable, attempting to start/enable service"
            if ! command -v dockerd >/dev/null 2>&1; then
                print_info "Docker Engine is missing, installing docker.io..."
                install_log "dockerd binary not found, installing docker.io package"
                sudo apt-get update
                sudo apt-get install -y docker.io
            fi
            if [ -d /run/systemd/system ]; then
                sudo systemctl enable --now docker 2>/dev/null || true
                sudo systemctl enable --now docker.socket 2>/dev/null || true
                sudo systemctl start docker 2>/dev/null || true
            else
                sudo service docker start 2>/dev/null || true
            fi

            local i
            for i in 1 2 3 4 5; do
                ${DOCKER_SUDO}docker info &>/dev/null && break
                sleep 2
            done
        fi

        if ! ${DOCKER_SUDO}docker info &>/dev/null; then
            local daemon_err
            daemon_err=$(${DOCKER_SUDO}docker info 2>&1) || true
            if echo "$daemon_err" | grep -qi "permission denied"; then
                DOCKER_SUDO="sudo "
                install_log "Docker socket permission denied after daemon start; switching to sudo for Docker commands"
            fi
        fi

        if ! ${DOCKER_SUDO}docker info &>/dev/null; then
            local daemon_err
            daemon_err=$(${DOCKER_SUDO}docker info 2>&1) || true
            install_log "Docker daemon check failed: ${daemon_err}"
            if [ -d /run/systemd/system ]; then
                install_log "systemctl status docker:"
                sudo systemctl status docker --no-pager >> "$INSTALL_LOG" 2>&1 || true
            fi
            log_fatal_error "Docker daemon is not running or unavailable. Try: sudo systemctl enable --now docker"
        fi

        return 0
    fi
    
    print_error "${MESSAGES[docker_not_found]}"
    
    if [ "$docker_found" = false ]; then
        echo "  Docker: Not found"
    fi
    if [ "$compose_found" = false ]; then
        echo "  Docker Compose: Not found"
    fi
    echo ""
    
    read -p "${MESSAGES[install_docker_prompt]} " install_docker_response
    
    if [[ "$install_docker_response" =~ ^[Yy]$ ]]; then
        install_docker
    else
        log_fatal_error "Docker is required for installation"
    fi
}

stop_existing_qemu_containers() {
    if command -v docker >/dev/null 2>&1; then
        print_info "Stopping existing qemu containers..."
        install_log "Stopping existing qemu containers before installation"
        ${DOCKER_SUDO}docker compose down --remove-orphans >/dev/null 2>&1 || true
        ${DOCKER_SUDO}docker ps -a --filter "name=qemu" --format "{{.ID}}" | xargs -r ${DOCKER_SUDO}docker rm -f >/dev/null 2>&1 || true
    fi
}

cleanup_containers_by_port() {
    local port="$1"
    local container_ids
    container_ids=$(${DOCKER_SUDO}docker ps -aq --filter "publish=${port}" 2>/dev/null || true)
    [ -z "$container_ids" ] && return 0

    print_info "Freeing port ${port} from previous Docker containers..."
    install_log "Freeing port ${port}, containers: ${container_ids}"
    ${DOCKER_SUDO}docker rm -f $container_ids >/dev/null 2>&1 || true
}

free_install_ports_from_previous_runs() {
    command -v docker >/dev/null 2>&1 || return 0
    [ ! -f .env ] && return 0

    local app_port app_ssl_port
    app_port=$(grep -E '^APP_PORT=' .env | cut -d '=' -f2)
    app_ssl_port=$(grep -E '^APP_SSL_PORT=' .env | cut -d '=' -f2)
    app_port=${app_port:-8081}
    app_ssl_port=${app_ssl_port:-8444}

    cleanup_containers_by_port "$app_port"
    [ "$app_ssl_port" != "$app_port" ] && cleanup_containers_by_port "$app_ssl_port"
}

install_docker() {
    print_info "${MESSAGES[installing_docker]}"
    install_log_section "Docker installation"

    local arch=$(uname -m)

    if [[ "$arch" == "riscv64" ]] || [[ "$arch" == "riscv32" ]]; then
        print_info "Installing docker.io for RISC-V..."
        install_log "Installing docker.io for RISC-V"
        sudo apt-get update
        sudo apt-get install -y docker.io docker-compose

        sudo systemctl start docker
        sudo systemctl enable docker
    else
        install_log "Fixing Docker package conflicts (half-installed or standalone vs plugins)"
        sudo dpkg --remove --force-remove-reinstreq docker-buildx docker-compose 2>/dev/null || true
        sudo apt-get remove -y docker-buildx docker-compose 2>/dev/null || true
        sudo dpkg --configure -a 2>/dev/null || true

        install_log "Running get.docker.com"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        safe_rm_f "${SCRIPT_DIR}/get-docker.sh"

        if ! docker compose version &>/dev/null; then
            install_log "Installing docker-compose-plugin (Docker repo)"
            sudo apt-get update
            sudo apt-get install -y docker-compose-plugin 2>/dev/null || true
        fi
        if ! docker compose version &>/dev/null; then
            install_log "docker compose plugin check: still missing, verifying docker works"
        else
            install_log "Docker and docker compose plugin OK"
        fi
    fi

    print_info "${MESSAGES[add_user_to_docker]}"
    sudo usermod -aG docker "$USER"
    install_log "User $USER added to docker group"
    print_success "${MESSAGES[docker_installed]}"
    echo ""
    print_warning "${MESSAGES[logout_required]}"
    echo ""
    read -p "${MESSAGES[logout_now_prompt]} " reboot_now
    if [[ "$reboot_now" =~ ^[Yy]$ ]]; then
        print_info "${MESSAGES[logging_out]}"
        install_log "User chose to reboot now"
        sleep 3
        if sudo systemctl reboot 2>/dev/null || sudo reboot 2>/dev/null; then
            :
        else
            print_warning "${MESSAGES[logout_manual]}"
            install_log "Automatic reboot failed or not available"
        fi
    else
        print_info "${MESSAGES[run_install_after_login]}"
        install_log "User chose not to reboot; script exits. User must re-run install.sh after reboot."
    fi
    exit 0
}

setup_qemu_dirs() {
    print_info "Creating QEMU Web Control directories..."
    install_log_section "QEMU directories setup"

    sudo mkdir -p /etc/QemuWebControl
    sudo mkdir -p /var/qemu/VM
    sudo mkdir -p /var/qemu/qmp
    sudo mkdir -p /var/lib/qemu/iso
    sudo mkdir -p /var/lib/qemu/iso-staging
    sudo mkdir -p /srv/iso

    sudo chmod 755 /var/qemu/qmp
    sudo chown root:root /var/qemu/qmp 2>/dev/null || true
    install_log "/var/qemu/qmp: root:root 755 (QEMU creates QMP sockets for preview)"

    local id_file="/etc/QemuWebControl/id"
    if [ ! -f "$id_file" ]; then
        local guid
        guid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
        if [ -z "$guid" ]; then
            guid=$(od -x /dev/urandom | head -1 | awk '{print $2$3$4$5$6$7$8$9}' | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
        fi
        echo "$guid" | sudo tee "$id_file" > /dev/null
        install_log "Created $id_file with GUID: $guid"
    else
        install_log "Id file already exists: $id_file"
    fi

    sudo chmod 755 /etc/QemuWebControl
    sudo chmod 644 "$id_file"
    sudo chmod 775 /var/qemu/VM
    sudo chmod 755 /var/lib/qemu/iso /srv/iso
    sudo chmod 775 /var/lib/qemu/iso-staging
    sudo chown root:root /etc/QemuWebControl "$id_file" 2>/dev/null || true
    sudo chown 33:33 /var/qemu/VM /var/lib/qemu/iso-staging 2>/dev/null || true

    print_success "Directories /etc/QemuWebControl, /var/qemu/VM, /var/qemu/qmp, /var/lib/qemu/iso, /srv/iso ready"
    install_log "QEMU directories: /etc/QemuWebControl, /var/qemu/VM, /var/qemu/qmp, /var/lib/qemu/iso, /srv/iso"

    sudo mkdir -p /etc/qemu
    local bridge_conf="/etc/qemu/bridge.conf"
    if [ ! -f "$bridge_conf" ] || ! grep -q '^allow ' "$bridge_conf" 2>/dev/null; then
        printf 'allow all\n' | sudo tee "$bridge_conf" > /dev/null
        sudo chmod 644 "$bridge_conf"
        sudo chown root:root "$bridge_conf"
        install_log "Created/updated $bridge_conf for QEMU bridge networking (allow all)"
    fi
}

setup_boot_images_service() {
    local script="${SCRIPT_DIR}/scripts/install-boot-images-service.sh"
    if [ ! -f "$script" ]; then
        install_log "ERROR: $script not found"
        add_install_error "install-boot-images-service.sh not found"
        exit 1
    fi
    export INSTALL_LOG
    bash "$script"
    cd "$SCRIPT_DIR"
}

setup_qemu_control_service() {
    local script="${SCRIPT_DIR}/scripts/install-control-service.sh"
    if [ ! -f "$script" ]; then
        install_log "ERROR: $script not found"
        add_install_error "install-control-service.sh not found"
        exit 1
    fi
    export INSTALL_LOG
    bash "$script"
    cd "$SCRIPT_DIR"
}

setup_env() {
    print_info "${MESSAGES[checking_env]}"
    
    if [ ! -f .env ]; then
        print_info "${MESSAGES[creating_env]}"
        cp .env.example .env
        print_success "${MESSAGES[env_created]}"
    fi

    ensure_qemu_targets_in_env
}

configure_database() {
    install_log "Starting database configuration"
    install_log_section "Database configuration"
    
    if [ "$NON_INTERACTIVE" = true ]; then
        db_choice=1
        install_log "Non-interactive: using Docker MariaDB (db_choice=1)"
    else
        echo ""
        echo "${MESSAGES[db_choice]}"
        echo "  ${MESSAGES[db_docker]}"
        echo "  ${MESSAGES[db_external]}"
        read -p "${MESSAGES[enter_choice]} [1]: " db_choice || db_choice=1
        db_choice=${db_choice:-1}
    fi
    install_log "Database choice: $db_choice"
    
    if [[ "$db_choice" == "2" ]]; then
        USE_DOCKER_DB=false
        configure_external_database
    else
        ARCH=$(uname -m)
        
        if [ "$ARCH" = "riscv64" ]; then
            print_warning "MariaDB Docker image is not available for RISC-V architecture"
            echo ""
            echo "The official MariaDB image does not support RISC-V (Orange Pi, VisionFive)."
            echo ""
            read -p "Switch to external MariaDB/MySQL? [Y/n]: " switch_external || switch_external=Y
            switch_external=${switch_external:-Y}
            
            if [[ "$switch_external" =~ ^[Yy]$ ]]; then
                USE_DOCKER_DB=false
                install_log "Switched to external DB (RISC-V)"
                configure_external_database
            else
                log_fatal_error "Docker MariaDB is not available on RISC-V. Please choose external database (option 2)."
            fi
        else
            USE_DOCKER_DB=true
            configure_docker_database
        fi
    fi
}

configure_docker_database() {
    install_log_section "Configuring Docker MariaDB"
    
    print_info "Using Docker MariaDB (isolated container)"
    install_log "Using Docker MariaDB"
    
    if [ ! -f docker/docker-compose.docker-db.yml ]; then
        log_fatal_error "docker/docker-compose.docker-db.yml not found!"
    fi
    
    sed -i "s/DB_HOST=.*/DB_HOST=db/" .env
    sed -i "s/DB_PORT=.*/DB_PORT=3306/" .env
    
    local db_root_pass=$(grep DB_ROOT_PASSWORD .env | cut -d '=' -f2)
    if [ -z "$db_root_pass" ]; then
        read -sp "Enter MariaDB root password [root_password]: " db_root_pass || db_root_pass=root_password
        echo ""
        db_root_pass=${db_root_pass:-root_password}
        sed -i "s/DB_ROOT_PASSWORD=.*/DB_ROOT_PASSWORD=$db_root_pass/" .env
    fi
    
    if [ ! -f docker-compose.yml.backup ]; then
        cp docker-compose.yml docker-compose.yml.backup
        install_log "Backed up docker-compose.yml"
    fi
    
    cp docker/docker-compose.docker-db.yml docker-compose.yml
    print_success "Using docker-compose with MariaDB container"
    install_log "Switched to docker/docker-compose.docker-db.yml"
    
    print_info "Database will be created automatically by MariaDB container"
}

configure_external_database() {
    # Получаем текущие значения из .env если они есть
    local current_host=$(grep DB_HOST .env 2>/dev/null | cut -d '=' -f2)
    local current_port=$(grep DB_PORT .env 2>/dev/null | cut -d '=' -f2)
    local current_name=$(grep DB_DATABASE .env 2>/dev/null | cut -d '=' -f2)
    local current_user=$(grep DB_USERNAME .env 2>/dev/null | cut -d '=' -f2)
    
    # Устанавливаем значения по умолчанию
    current_host=${current_host:-localhost}
    current_port=${current_port:-3306}
    current_name=${current_name:-qemu_control}
    current_user=${current_user:-qemu_user}
    
    echo ""
    print_info "For secure localhost database connection, use Host Network Mode"
    echo ""
    echo "Network mode options:"
    echo "  1) Host Network - DB_HOST=localhost (secure, recommended)"
    echo "  2) Bridge Network - DB_HOST=gateway IP (default)"
    echo ""
    read -p "Select network mode [1-2, default: 1]: " network_mode || network_mode=1
    network_mode=${network_mode:-1}
    
    USE_HOST_NETWORK=false
    if [ "$network_mode" = "1" ]; then
        USE_HOST_NETWORK=true
        print_success "Using Host Network Mode (secure localhost access)"
        current_host="localhost"
    else
        print_info "Using Bridge Network Mode (requires gateway IP)"
        # Gateway IP будет установлен позже
    fi
    
    echo ""
    
    read -p "${MESSAGES[db_host]} [$current_host]: " db_host || db_host="$current_host"
    db_host=${db_host:-$current_host}
    
    if [ "$db_host" = "localhost" ] || [ "$db_host" = "127.0.0.1" ]; then
        [ "$db_host" = "localhost" ] && db_host="127.0.0.1" && print_info "localhost -> 127.0.0.1 (PDO uses TCP)"
        if [ "$USE_HOST_NETWORK" = false ]; then
            print_warning "DB_HOST=localhost requires Host Network Mode (Docker cannot reach host localhost in bridge mode)"
            print_info "Switching to Host Network Mode automatically"
            USE_HOST_NETWORK=true
        fi
    fi
    
    read -p "${MESSAGES[db_port]} [$current_port]: " db_port || db_port="$current_port"
    db_port=${db_port:-$current_port}
    
    read -p "${MESSAGES[db_name]} [$current_name]: " db_name || db_name="$current_name"
    db_name=${db_name:-$current_name}
    
    read -p "${MESSAGES[db_user]} [$current_user]: " db_user || db_user="$current_user"
    db_user=${db_user:-$current_user}
    
    read -sp "${MESSAGES[db_pass]} " db_pass || db_pass=""
    echo ""
    
    # Если пароль пустой, запросить еще раз с предупреждением
    if [ -z "$db_pass" ]; then
        echo ""
        print_warning "Password cannot be empty!"
        read -sp "${MESSAGES[db_pass]} " db_pass || db_pass=""
        echo ""
    fi
    
    # Обновляем .env
    sed -i "s/DB_HOST=.*/DB_HOST=$db_host/" .env
    sed -i "s/DB_PORT=.*/DB_PORT=$db_port/" .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=$db_name/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=$db_user/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$db_pass/" .env
    
    # Проверяем наличие mysql клиента
    if ! command -v mysql &> /dev/null; then
        print_warning "MySQL client not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y mysql-client mariadb-client 2>/dev/null || sudo apt-get install -y default-mysql-client 2>/dev/null
    fi
    
    # Проверяем подключение и создаем БД если нужно
    print_info "${MESSAGES[testing_connection]}"
    
    if mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "SELECT 1" 2>/tmp/mysql_error.log; then
        print_success "${MESSAGES[connection_success]}"
        
        # Проверяем существование БД
        if ! mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "USE $db_name" 2>/dev/null; then
            print_info "${MESSAGES[creating_database]}"
            
            # Пытаемся создать от имени пользователя
            if mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci" 2>/tmp/mysql_create_error.log; then
                # Проверяем, что БД действительно создалась
                if mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "USE $db_name" 2>/dev/null; then
                    print_success "${MESSAGES[database_created]}"
                else
                    print_error "Database creation reported success but database not found!"
                    cat /tmp/mysql_create_error.log
                    echo ""
                    print_warning "Trying with root credentials..."
                    read -sp "${MESSAGES[db_root_pass]}: " db_root_pass || db_root_pass=""
                    echo ""
                    create_database_with_root "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "$db_root_pass"
                fi
            else
                # Если не получилось, запрашиваем root пароль
                echo ""
                print_warning "Cannot create database with user credentials"
                if [ -f /tmp/mysql_create_error.log ]; then
                    echo "Error details:"
                    cat /tmp/mysql_create_error.log
                fi
                echo ""
                read -sp "${MESSAGES[db_root_pass]}: " db_root_pass || db_root_pass=""
                echo ""
                create_database_with_root "$db_host" "$db_port" "$db_name" "$db_user" "$db_pass" "$db_root_pass"
            fi
        else
            print_success "${MESSAGES[database_exists]}"
        fi
    else
        print_error "${MESSAGES[connection_failed]}"
        echo "Error details:"
        [ -f /tmp/mysql_error.log ] && cat /tmp/mysql_error.log
        echo ""
        log_fatal_error "Database connection failed. Check credentials and try again."
    fi
    
    safe_rm_f /tmp/mysql_error.log /tmp/mysql_create_error.log 2>/dev/null || true
}

create_database_with_root() {
    local db_host=$1
    local db_port=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    local db_root_pass=$6
    
    # Создаем БД от root
    if mysql -h "$db_host" -P "$db_port" -u root -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci" 2>/tmp/mysql_root_error.log; then
        # Проверяем, что БД действительно создалась
        if mysql -h "$db_host" -P "$db_port" -u root -p"$db_root_pass" -e "USE $db_name" 2>/dev/null; then
            print_success "${MESSAGES[database_created]}"
            
            # Назначаем права пользователю
            print_info "${MESSAGES[grant_privileges]}"
            mysql -h "$db_host" -P "$db_port" -u root -p"$db_root_pass" 2>/tmp/mysql_grant_error.log << EOF
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';
CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_pass}';
DROP USER IF EXISTS '${db_user}'@'172.17.0.%';
DROP USER IF EXISTS '${db_user}'@'172.%.%.%';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
EOF
            
            if [ $? -eq 0 ]; then
                print_success "${MESSAGES[privileges_granted]}"
                
                # Финальная проверка
                if mysql -h "$db_host" -P "$db_port" -u "$db_user" -p"$db_pass" -e "USE $db_name" 2>/dev/null; then
                    print_success "Database verification successful"
                else
                    print_error "Database created but user cannot access it!"
                    [ -f /tmp/mysql_grant_error.log ] && cat /tmp/mysql_grant_error.log
                    log_fatal_error "Database created but user cannot access it"
                fi
            else
                print_error "Failed to grant privileges"
                [ -f /tmp/mysql_grant_error.log ] && cat /tmp/mysql_grant_error.log
                log_fatal_error "Failed to grant database privileges"
            fi
        else
            print_error "Database creation reported success but database not found!"
            [ -f /tmp/mysql_root_error.log ] && cat /tmp/mysql_root_error.log
            log_fatal_error "Database creation reported success but database not found"
        fi
    else
        print_error "${MESSAGES[connection_failed]}"
        echo "Error details:"
        [ -f /tmp/mysql_root_error.log ] && cat /tmp/mysql_root_error.log
        log_fatal_error "Database connection failed"
    fi
    
    safe_rm_f /tmp/mysql_root_error.log /tmp/mysql_grant_error.log 2>/dev/null || true
    
    # Применяем выбранную конфигурацию сети
    ARCH=$(uname -m)
    
    if [ "$USE_HOST_NETWORK" = true ]; then
        print_info "Configuring Host Network Mode..."
        
        if [ -f docker/docker-compose.host-network.yml ]; then
            # Бэкап оригинального docker-compose.yml
            if [ ! -f docker-compose.yml.backup ]; then
                cp docker-compose.yml docker-compose.yml.backup
                print_info "Backed up docker-compose.yml"
            fi
            
            # Переключаемся на host network
            cp docker/docker-compose.host-network.yml docker-compose.yml
            print_success "Switched to Host Network Mode"
            
            # Обновляем nginx конфигурацию
            if [ -f docker/nginx/conf.d/default.host-network.conf ]; then
                cp docker/nginx/conf.d/default.host-network.conf docker/nginx/conf.d/default.conf
                print_success "Updated nginx configuration for host network"
            fi
            
            # Устанавливаем стандартные порты для host network
            sed -i "s/APP_PORT=.*/APP_PORT=80/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=443/" .env
            
            print_success "Using secure localhost connection!"
            print_info "Database: $db_host:$db_port (localhost - secure)"
            print_info "Ports: 80 (HTTP), 443 (HTTPS)"
            
            # Проверяем что MariaDB настроена правильно
            if grep -q "^bind-address.*0.0.0.0" /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null; then
                print_warning "MariaDB bind-address is 0.0.0.0"
                print_info "For host network mode, you can use 127.0.0.1 (more secure)"
                echo ""
                read -p "Change bind-address to 127.0.0.1? [Y/n]: " change_bind
                change_bind=${change_bind:-Y}
                
                if [[ "$change_bind" =~ ^[Yy]$ ]]; then
                    sudo sed -i 's/^bind-address.*0.0.0.0/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
                    sudo systemctl restart mariadb
                    print_success "MariaDB now listening only on localhost (secure!)"
                fi
            fi
        else
            print_warning "docker/docker-compose.host-network.yml not found"
            print_warning "Host network mode not available"
        fi
    elif [ "$ARCH" = "riscv64" ]; then
        # Для RISC-V переключаем на docker-compose без БД контейнера
        print_info "Detected RISC-V architecture"
        
        if [ -f docker/docker-compose.riscv.yml ]; then
            # Бэкап оригинального docker-compose.yml
            if [ ! -f docker-compose.yml.backup ]; then
                cp docker-compose.yml docker-compose.yml.backup
                print_info "Backed up docker-compose.yml"
            fi
            
            # Переключаемся на версию без БД
            cp docker/docker-compose.riscv.yml docker-compose.yml
            print_success "Switched to RISC-V docker-compose (without DB container)"
            print_info "Using external database: $db_host:$db_port"
        else
            print_warning "docker/docker-compose.riscv.yml not found"
            print_warning "You may need to remove 'db:' service from docker-compose.yml manually"
        fi
    fi
}

generate_ssl() {
    install_log_section "Generating SSL certificate"
    print_info "${MESSAGES[generating_ssl]}"

    mkdir -p docker/nginx/ssl

    local san="DNS:localhost,IP:127.0.0.1"
    local hostname_val
    hostname_val=$(hostname 2>/dev/null || true)
    [ -n "$hostname_val" ] && [ "$hostname_val" != "localhost" ] && san="${san},DNS:${hostname_val}"
    while IFS= read -r ip; do
        [ -n "$ip" ] && san="${san},IP:${ip}"
    done < <(ip -4 addr show scope global 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]}' | sort -u || true)
    install_log "SSL SAN: ${san}"

    local ssl_out
    if ! ssl_out=$(openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout docker/nginx/ssl/server.key \
        -out docker/nginx/ssl/server.crt \
        -subj "/C=RU/ST=Moscow/L=Moscow/O=QEMU Web Control/CN=localhost" \
        -addext "subjectAltName=${san}" 2>&1); then
        install_log "openssl error: $ssl_out"
        install_log "Retrying without -addext (older OpenSSL fallback)..."
        if ! ssl_out=$(openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout docker/nginx/ssl/server.key \
            -out docker/nginx/ssl/server.crt \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=QEMU Web Control/CN=localhost" 2>&1); then
            install_log "openssl fallback error: $ssl_out"
            log_fatal_error "SSL certificate generation failed. openssl output: $ssl_out"
        fi
        install_log "SSL certificate generated (without SAN, older OpenSSL)"
    else
        install_log "SSL certificate generated with SAN: ${san}"
    fi

    chmod 600 docker/nginx/ssl/server.key
    install_log "SSL: docker/nginx/ssl/server.{crt,key} — $(openssl version 2>/dev/null)"
    print_success "${MESSAGES[ssl_generated]}"
}

ensure_localhost_uses_host_network() {
    [ ! -f .env ] && return 0
    
    local db_host=$(grep DB_HOST .env | cut -d '=' -f2)
    local uses_host_network="no"
    grep -q "network_mode.*host" docker-compose.yml 2>/dev/null && uses_host_network="yes"
    
    install_log "ensure_localhost_uses_host_network: DB_HOST=$db_host, uses_host_network=$uses_host_network"
    
    if [ "$db_host" = "localhost" ] || [ "$db_host" = "127.0.0.1" ]; then
        if [ "$db_host" = "localhost" ]; then
            sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
            print_info "DB_HOST=localhost -> 127.0.0.1 (PDO uses TCP, avoids socket error)"
            install_log "DB_HOST changed from localhost to 127.0.0.1"
        fi
        if [ "$uses_host_network" != "yes" ]; then
            print_warning "DB_HOST=$db_host but docker-compose is not in host network mode"
            print_info "Switching to Host Network Mode (required for localhost DB access)"
            
            if [ -f docker/docker-compose.host-network.yml ]; then
                [ ! -f docker-compose.yml.backup ] && cp docker-compose.yml docker-compose.yml.backup
                cp docker/docker-compose.host-network.yml docker-compose.yml
                [ -f docker/nginx/conf.d/default.host-network.conf ] && cp docker/nginx/conf.d/default.host-network.conf docker/nginx/conf.d/default.conf
                sed -i "s/APP_PORT=.*/APP_PORT=80/" .env
                sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=443/" .env
                print_success "Switched to Host Network Mode"
                install_log "Switched to host network mode for localhost DB"
            else
                log_fatal_error "docker/docker-compose.host-network.yml not found!"
            fi
        fi
    fi
}

port_in_use() {
    local port=$1
    ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "
}

check_apache_port_conflict() {
    [ ! -f .env ] && return 0

    command -v apache2 &>/dev/null || command -v httpd &>/dev/null || return 0

    local app_port app_ssl_port
    app_port=$(grep -E '^APP_PORT=' .env | cut -d '=' -f2)
    app_ssl_port=$(grep -E '^APP_SSL_PORT=' .env | cut -d '=' -f2)
    app_port=${app_port:-80}
    app_ssl_port=${app_ssl_port:-443}

    local conflict=false
    ss -tlnp 2>/dev/null | grep -q ":${app_port} " && conflict=true
    ss -tlnp 2>/dev/null | grep -q ":${app_ssl_port} " && conflict=true

    [ "$conflict" = false ] && return 0

    print_warning "${MESSAGES[apache_port_conflict_detected]}"
    print_info "${MESSAGES[apache_port_conflict_fixing]}"
    install_log "Apache2 conflict: ports ${app_port}/${app_ssl_port} in use — finding free ports"

    local new_port=$app_port
    if ss -tlnp 2>/dev/null | grep -q ":${new_port} "; then
        new_port=8081
        while ss -tlnp 2>/dev/null | grep -q ":${new_port} " && [ "$new_port" -lt 9000 ]; do
            new_port=$((new_port + 1))
        done
    fi

    local new_ssl_port=$app_ssl_port
    if ss -tlnp 2>/dev/null | grep -q ":${new_ssl_port} " || [ "$new_ssl_port" -eq "$new_port" ]; then
        new_ssl_port=8444
        while { ss -tlnp 2>/dev/null | grep -q ":${new_ssl_port} " || [ "$new_ssl_port" -eq "$new_port" ]; } && [ "$new_ssl_port" -lt 9000 ]; do
            new_ssl_port=$((new_ssl_port + 1))
        done
    fi

    sed -i "s/APP_PORT=.*/APP_PORT=${new_port}/" .env
    sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=${new_ssl_port}/" .env

    print_success "${MESSAGES[apache_port_conflict_fixed]}: HTTP=${new_port}, HTTPS=${new_ssl_port}"
    install_log "Apache2 conflict resolved: APP_PORT=${new_port}, APP_SSL_PORT=${new_ssl_port}"
}

check_and_fix_apache_nginx_conflict() {
    [ ! -f .env ] || [ ! -f docker-compose.yml ] && return 0
    grep -q "network_mode.*host" docker-compose.yml 2>/dev/null || return 0

    port_in_use 80 || port_in_use 443 || return 0

    print_warning "${MESSAGES[apache_nginx_conflict]}"
    print_info "${MESSAGES[apache_nginx_fixing]}"
    install_log "Apache/nginx conflict: running scripts/fix-apache-nginx-conflict.sh"

    if [ -f "$SCRIPT_DIR/scripts/fix-apache-nginx-conflict.sh" ]; then
        bash "$SCRIPT_DIR/scripts/fix-apache-nginx-conflict.sh" --no-restart 2>&1 | tee -a "$INSTALL_LOG"
        install_log "scripts/fix-apache-nginx-conflict.sh completed"
    else
        log_fatal_error "scripts/fix-apache-nginx-conflict.sh not found"
    fi
}

check_and_fix_ports() {
    local app_port=$(grep APP_PORT .env | cut -d '=' -f2)
    local app_ssl_port=$(grep APP_SSL_PORT .env | cut -d '=' -f2)
    
    # Функция проверки порта
    check_port() {
        local port=$1
        if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            return 0  # Port is in use
        else
            return 1  # Port is free
        fi
    }
    
    local port_conflict=false
    
    # Проверяем HTTP порт
    if check_port $app_port; then
        print_warning "Port $app_port is already in use"
        port_conflict=true
    fi
    
    # Проверяем HTTPS порт
    if check_port $app_ssl_port; then
        print_warning "Port $app_ssl_port is already in use"
        port_conflict=true
    fi
    
    if [ "$port_conflict" = true ]; then
        echo ""
        print_warning "Port conflict detected!"
        
        # Ищем свободные порты
        local new_port=8081
        while check_port $new_port && [ $new_port -lt 9000 ]; do
            new_port=$((new_port + 1))
        done
        
        local new_ssl_port=8444
        while check_port $new_ssl_port && [ $new_ssl_port -lt 9000 ]; do
            new_ssl_port=$((new_ssl_port + 1))
        done
        
        echo ""
        print_info "Suggested free ports:"
        echo "  HTTP:  $new_port"
        echo "  HTTPS: $new_ssl_port"
        echo ""
        
        read -p "Use these ports? [Y/n]: " use_ports
        use_ports=${use_ports:-Y}
        
        if [[ "$use_ports" =~ ^[Yy]$ ]]; then
            sed -i "s/APP_PORT=.*/APP_PORT=$new_port/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=$new_ssl_port/" .env
            print_success "Ports updated: HTTP=$new_port, HTTPS=$new_ssl_port"
        else
            log_fatal_error "Installation cannot continue with port conflict. Run: ./scripts/fix-port-conflict.sh"
        fi
    fi
}

configure_boot_media_upload_limits() {
    install_log_section "Boot Media upload limits (10GB)"
    local php_ini="${SCRIPT_DIR}/docker/php/local.ini"
    if [ -f "$php_ini" ]; then
        if ! grep -q "upload_max_filesize = 10G" "$php_ini" 2>/dev/null; then
            sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 10G/' "$php_ini" 2>/dev/null || true
            sed -i 's/^post_max_size = .*/post_max_size = 10G/' "$php_ini" 2>/dev/null || true
        fi
        install_log "PHP upload limits: 10G (docker/php/local.ini)"
    fi
    for nginx_conf in "${SCRIPT_DIR}"/docker/nginx/conf.d/default*.conf; do
        [ -f "$nginx_conf" ] || continue
        if ! grep -q "client_max_body_size 10G" "$nginx_conf" 2>/dev/null; then
            sed -i 's/client_max_body_size [0-9]*[MmGg];/client_max_body_size 10G;/g' "$nginx_conf" 2>/dev/null || true
        fi
        install_log "Nginx client_max_body_size: 10G ($(basename "$nginx_conf"))"
    done
}

run_installation() {
    install_log_section "Starting run_installation"
    
    configure_boot_media_upload_limits
    fix_permissions
    install_log "Permissions fixed"
    ensure_localhost_uses_host_network
    install_log "Network mode verified"
    check_and_fix_apache_nginx_conflict
    install_log "Apache/nginx conflict check done"

    local compose_cmd="${DOCKER_SUDO}docker compose"
    if ! ${DOCKER_SUDO}docker compose version &> /dev/null; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="${DOCKER_SUDO}docker-compose"
        else
            log_fatal_error "Docker Compose not found!"
        fi
    fi
    
    # Проверяем и исправляем конфликты портов
    free_install_ports_from_previous_runs
    check_and_fix_ports
    
    print_info "${MESSAGES[building_containers]}"
    install_log_section "Building containers"
    local php_ver
    php_ver=$(grep -E '^PHP_VERSION=' .env 2>/dev/null | cut -d '=' -f2) || php_ver="8.3"
    install_log "PHP_VERSION=${php_ver} (set in .env to change; e.g. 8.4 when available)"
    $compose_cmd build 2>&1 | tee -a "$INSTALL_LOG"

    print_info "${MESSAGES[starting_containers]}"
    install_log_section "Starting containers"
    $compose_cmd up -d 2>&1 | tee /tmp/docker_up.log | tee -a "$INSTALL_LOG"
    
    # Проверяем на ошибку порта в выводе
    if grep -q "address already in use" /tmp/docker_up.log; then
        print_error "Port conflict occurred during startup"
        echo ""
        print_info "Attempting automatic fix..."
        
        # Пробуем еще раз найти свободные порты
        check_and_fix_ports
        
        # Пробуем запустить снова
        print_info "Retrying container startup..."
        $compose_cmd down 2>/dev/null
        $compose_cmd up -d
        
        if [ $? -ne 0 ]; then
            log_fatal_error "Failed to start containers. Run: ./scripts/fix-port-conflict.sh"
        fi
    fi
    
    safe_rm_f /tmp/docker_up.log 2>/dev/null || true

    if ! grep -q "network_mode.*host" "${SCRIPT_DIR}/docker-compose.yml" 2>/dev/null; then
        local fix_script="${SCRIPT_DIR}/scripts/fix-boot-media-docker.sh"
        if [ -f "$fix_script" ] && command -v docker &>/dev/null; then
            print_info "Configuring UFW for Docker network (ports 50052, 50054, 50055)..."
            if sudo "$fix_script" 2>&1 | tee -a "$INSTALL_LOG"; then
                install_log "fix-boot-media-docker.sh completed (after containers up)"
            else
                print_warning "fix-boot-media-docker.sh had issues, check manually"
            fi
        fi
    fi

    if [ "${USE_DOCKER_DB:-false}" = true ]; then
        print_info "Waiting for MariaDB container to initialize..."
        install_log "Waiting for MariaDB (USE_DOCKER_DB=true)"
        sleep 15
    else
        sleep 5
    fi
    fix_permissions
    $compose_cmd exec -T app sh -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rwX storage bootstrap/cache'
    install_log "Container permissions adjusted: www-data on storage/bootstrap/cache"
    
    print_info "${MESSAGES[installing_dependencies]}"
    install_log_section "Installing Composer dependencies"
    if [ ! -f composer.lock ]; then
        print_warning "composer.lock not found: dependency resolution can take longer"
        install_log "composer.lock not found: composer install may run longer (dependency resolution)"
    fi

    (
        $compose_cmd exec -T app composer install --no-interaction --prefer-dist --optimize-autoloader --profile 2>&1 | tee -a "$INSTALL_LOG"
    ) &
    local composer_pid=$!
    local composer_waited=0
    while kill -0 $composer_pid 2>/dev/null; do
        sleep 20
        composer_waited=$((composer_waited + 20))
        if kill -0 $composer_pid 2>/dev/null; then
            print_info "Composer is still running... ${composer_waited}s"
            install_log "Composer still running (${composer_waited}s)"
        fi
    done
    wait $composer_pid || log_fatal_error "Composer install failed"

    print_info "Clearing Laravel caches (safe mode)..."
    $compose_cmd exec -T app php artisan config:clear 2>/dev/null || true
    $compose_cmd exec -T app php artisan route:clear 2>/dev/null || true
    $compose_cmd exec -T app php artisan view:clear 2>/dev/null || true
    $compose_cmd exec -T app php artisan event:clear 2>/dev/null || true
    
    print_info "${MESSAGES[generating_key]}"
    $compose_cmd exec -T app php artisan key:generate --force
    
    print_info "${MESSAGES[creating_storage_link]}"
    $compose_cmd exec -T app php artisan storage:link
    
    # Проверяем подключение к БД перед миграциями
    print_info "Checking database connection..."
    install_log_section "Database connection check"
    
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    
    install_log "DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_NAME=$DB_NAME DB_USER=$DB_USER"
    
    NETWORK_MODE=$(${DOCKER_SUDO}docker inspect $($compose_cmd ps -q app 2>/dev/null) --format='{{.HostConfig.NetworkMode}}' 2>/dev/null || echo "unknown")
    install_log "Container network mode: $NETWORK_MODE"
    
    local max_attempts=5
    local attempt=1
    local db_connected=false
    
    while [ $attempt -le $max_attempts ]; do
        local db_output
        db_output=$($compose_cmd exec -T app php artisan db:show 2>&1) || true
        echo "$db_output" >> "$INSTALL_LOG"
        
        if echo "$db_output" | grep -qE "MariaDB|Connection.*mysql"; then
            db_connected=true
            install_log "Database connection successful at attempt $attempt"
            break
        fi
        
        print_warning "Database connection attempt $attempt/$max_attempts failed, waiting 3 seconds..."
        install_log "Attempt $attempt failed. Output: $db_output"
        
        if [ $attempt -eq 1 ] && { [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; }; then
            if [ "$NETWORK_MODE" != "host" ]; then
                print_warning "DB_HOST=localhost with bridge network - switching to host network"
                install_log "Switching to host network for localhost DB"
                ensure_localhost_uses_host_network
                $compose_cmd down 2>/dev/null
                sleep 2
                $compose_cmd up -d
                sleep 5
            fi
        fi
        
        sleep 3
        attempt=$((attempt + 1))
    done
    
    if [ "$db_connected" = false ]; then
        print_error "Cannot connect to database!"
        install_log "Database connection failed after $max_attempts attempts"
        
        echo ""
        echo "Database configuration:"
        echo "  Host: $DB_HOST"
        echo "  Port: $DB_PORT"
        echo "  Database: $DB_NAME"
        echo "  User: $DB_USER"
        echo ""
        
        DB_SHOW_ERROR=$($compose_cmd exec -T app php artisan db:show 2>&1) || true
        echo "Error details:"
        echo "$DB_SHOW_ERROR"
        echo ""
        install_log "Last db:show output: $DB_SHOW_ERROR"
        
        if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
            print_warning "DB_HOST=localhost requires Host Network Mode"
            read -p "Switch to Host Network Mode and retry? [Y/n]: " switch_host
            switch_host=${switch_host:-Y}
            
            if [[ "$switch_host" =~ ^[Yy]$ ]]; then
                ensure_localhost_uses_host_network
                $compose_cmd down 2>/dev/null
                $compose_cmd up -d
                sleep 5
                
                if $compose_cmd exec -T app php artisan db:show 2>&1 | grep -qE "MariaDB|Connection.*mysql"; then
                    print_success "Database connection successful after switching to host network!"
                    db_connected=true
                fi
            fi
        fi
        
        if [ "$db_connected" = false ]; then
            print_warning "Attempting automatic diagnosis and fix..."
            echo ""
            
            read -p "Run automatic database connection diagnostic? [Y/n]: " run_diag
            run_diag=${run_diag:-Y}
            
            if [[ "$run_diag" =~ ^[Yy]$ ]]; then
                if [ -f "$SCRIPT_DIR/scripts/diagnose-mariadb.sh" ]; then
                print_info "Running MariaDB diagnostic..."
                echo ""
                bash "$SCRIPT_DIR/scripts/diagnose-mariadb.sh"
                echo ""
                
                # Проверяем подключение снова
                print_info "Retrying database connection..."
                sleep 2
                
                if $compose_cmd exec -T app php artisan db:show 2>&1 | grep -qE "MariaDB|Connection.*mysql"; then
                    print_success "Database connection fixed!"
                    db_connected=true
                else
                    print_error "Connection still fails"
                    
                    # Предлагаем альтернативные решения
                    echo ""
                    print_warning "Alternative solutions:"
                    echo ""
                    
                    if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
                        echo "1) Fix database connection for Docker:"
                        echo "   ./scripts/fix-db-connection.sh"
                        echo ""
                        echo "2) Setup database:"
                        echo "   ./scripts/setup-database.sh"
                        echo ""
                    elif [ "$DB_HOST" = "db" ]; then
                        echo "1) Use external database (recommended for RISC-V):"
                        echo "   ./scripts/fix-database-riscv.sh"
                        echo ""
                    else
                        echo "1) Check MariaDB configuration:"
                        echo "   ss -tlnp | grep 3306"
                        echo ""
                        echo "2) Fix connection:"
                        echo "   ./scripts/fix-db-connection.sh"
                        echo ""
                    fi
                fi
            else
                print_warning "scripts/diagnose-mariadb.sh not found"
                
                # Показываем ручные решения
                if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
                    print_warning "You are using external database"
                    echo ""
                    echo "Docker containers cannot connect to 'localhost'"
                    echo ""
                    echo "Quick fix:"
                    echo "  1. Change DB_HOST to Docker gateway:"
                    echo "     sed -i 's/DB_HOST=.*/DB_HOST=172.17.0.1/' .env"
                    echo ""
                    echo "  2. Configure MariaDB:"
                    echo "     sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf"
                    echo "     Set: bind-address = 0.0.0.0"
                    echo ""
                    echo "  3. Update user privileges:"
                    echo "     sudo mysql -u root -e \"CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}'; GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'%'; DROP USER IF EXISTS '${DB_USER}'@'172.%.%.%'; DROP USER IF EXISTS '${DB_USER}'@'172.17.0.%'; FLUSH PRIVILEGES;\""
                    echo ""
                    echo "  4. Restart MariaDB:"
                    echo "     sudo systemctl restart mariadb"
                    echo ""
                elif [ "$DB_HOST" = "db" ]; then
                    print_warning "You are using Docker database"
                    echo ""
                    echo "Checking db container..."
                    if ! $compose_cmd ps | grep -q "db.*Up"; then
                        print_error "Database container is not running!"
                        echo ""
                        echo "This is likely a RISC-V architecture issue."
                        echo "MariaDB Docker image is not available for RISC-V."
                        echo ""
                        echo "Solution: Use external database"
                        echo "  ./scripts/fix-database-riscv.sh"
                    fi
                fi
            fi
        fi
        fi
        
        if [ "$db_connected" = false ]; then
            echo ""
            print_info "To fix: ./scripts/diagnose-mariadb.sh or ./scripts/fix-db-connection.sh or ./scripts/setup-database.sh"
            log_fatal_error "Cannot connect to database. Database is required."
        fi
    fi
    
    print_success "Database connection OK"
    print_info "${MESSAGES[running_migrations]}"
    $compose_cmd exec -T app php artisan migrate --force
    
    print_info "${MESSAGES[seeding_database]}"
    $compose_cmd exec -T app php artisan db:seed --force
    
    print_info "Clearing Laravel caches..."
    $compose_cmd exec -T app php artisan optimize:clear || true
    
    print_info "${MESSAGES[installing_npm]}"
    install_log_section "Installing NPM dependencies"
    safe_rm_rf "${SCRIPT_DIR}/node_modules"
    mkdir -p node_modules
    sudo chown -R 1000:1000 node_modules
    chmod -R 775 node_modules
    (
        $compose_cmd exec -T app env CI=true npm install 2>&1 | tee -a "$INSTALL_LOG"
    ) &
    local npm_pid=$!
    local npm_waited=0
    while kill -0 $npm_pid 2>/dev/null; do
        sleep 20
        npm_waited=$((npm_waited + 20))
        if kill -0 $npm_pid 2>/dev/null; then
            print_info "NPM install is still running... ${npm_waited}s"
            install_log "NPM install still running (${npm_waited}s)"
        fi
    done
    wait $npm_pid || log_fatal_error "NPM install failed"
    
    print_info "${MESSAGES[building_assets]}"
    install_log_section "Building frontend assets"
    $compose_cmd exec -T app npm run build 2>&1 | tee -a "$INSTALL_LOG"
    
    fix_permissions
    $compose_cmd exec -T app sh -lc 'chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rwX storage bootstrap/cache'
    install_log "Final container permissions adjusted: www-data on storage/bootstrap/cache"
}

handle_exit() {
    local code=$1
    if [ "$code" != "0" ]; then
        local errors=()
        if [ -f "${INSTALL_ERRORS_FILE:-}" ]; then
            while IFS= read -r err; do
                [ -n "$err" ] && errors+=("$err")
            done < "$INSTALL_ERRORS_FILE" 2>/dev/null || true
            safe_rm_f "$INSTALL_ERRORS_FILE" 2>/dev/null || true
        fi
        if [ -n "${INSTALL_LOG:-}" ]; then
            install_log_section "${MESSAGES[installation_log_failed]:-Installation completed with errors} (exit code: $code)"
            if [ ${#errors[@]} -gt 0 ]; then
                install_log "${MESSAGES[errors_list]:-Errors:}"
                for err in "${errors[@]}"; do
                    install_log "  - $err"
                done
            fi
        fi
        echo ""
        print_header
        format_line "${MESSAGES[installation_failed]:-Installation completed with errors}"
        echo "${MESSAGES[separator]}"
        if [ ${#errors[@]} -gt 0 ]; then
            format_line "${MESSAGES[errors_list]:-Errors:}"
            for err in "${errors[@]}"; do
                format_line "  - $err"
            done
        fi
        format_line "Install log: $INSTALL_LOG"
        print_footer
    fi
}

show_completion_message() {
    install_log_section "${MESSAGES[installation_log_success]:-Installation completed successfully (no errors)}"
    install_log "Log saved to: $INSTALL_LOG"
    
    APP_URL=$(grep -E '^APP_URL=' .env 2>/dev/null | cut -d '=' -f2-)
    APP_URL=${APP_URL:-http://localhost}
    install_log "APP_URL from .env: ${APP_URL}"
    APP_PORT=$(grep -E '^APP_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    APP_SSL_PORT=$(grep -E '^APP_SSL_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    if ! echo "$APP_URL" | grep -qE ':[0-9]+/?$'; then
        [ -n "$APP_PORT" ] && APP_URL="http://localhost:${APP_PORT}"
        install_log "APP_URL after port append: ${APP_URL}"
    fi

    local primary_ip app_host url_no_proto
    primary_ip=$(resolve_primary_ip)
    install_log "primary_ip (for APP_URL): ${primary_ip:-not resolved}"
    url_no_proto="${APP_URL#*://}"
    app_host="${url_no_proto%%[:/]*}"
    install_log "APP_URL host part: ${app_host}"
    if [ -n "$primary_ip" ] && { [ "$app_host" = "localhost" ] || [ "$app_host" = "127.0.0.1" ]; }; then
        case "$APP_URL" in
            http://localhost*) APP_URL="http://${primary_ip}${APP_URL#http://localhost}" ;;
            https://localhost*) APP_URL="https://${primary_ip}${APP_URL#https://localhost}" ;;
            http://127.0.0.1*) APP_URL="http://${primary_ip}${APP_URL#http://127.0.0.1}" ;;
            https://127.0.0.1*) APP_URL="https://${primary_ip}${APP_URL#https://127.0.0.1}" ;;
        esac
        sed -i "s|^APP_URL=.*|APP_URL=${APP_URL}|" .env
        install_log "APP_URL replaced localhost with ${primary_ip}, written to .env: ${APP_URL} (for VNC WebSocket from other computers)"
    else
        install_log "APP_URL not changed (host=${app_host}, primary_ip=${primary_ip:-empty})"
    fi

    APP_HTTPS="$APP_URL"
    if [[ "$APP_HTTPS" == http://* ]]; then
        APP_HTTPS="https://${APP_HTTPS#http://}"
    fi
    if [ -n "${APP_PORT:-}" ] && [ -n "${APP_SSL_PORT:-}" ] && [[ "$APP_HTTPS" == *":${APP_PORT}" ]]; then
        APP_HTTPS="${APP_HTTPS%:${APP_PORT}}:${APP_SSL_PORT}"
    fi

    local vnc_ws_host=""
    local interfaces=()
    mapfile -t interfaces < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -Ev '^(lo|docker.*|br-.*|veth.*)$')
    echo ""
    echo "${MESSAGES[vnc_console_iface_prompt]}"
    echo "  0) ${MESSAGES[vnc_console_localhost]}"
    local i=1
    local iface
    for iface in "${interfaces[@]}"; do
        local ipv4_info
        ipv4_info=$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 | head -1)
        [ -z "$ipv4_info" ] && ipv4_info="-"
        echo "  $i) $iface - ${ipv4_info}:50055"
        i=$((i + 1))
    done
    echo ""
    local selected_idx
    read -p "Select [0]: " selected_idx
    selected_idx=${selected_idx:-0}
    if [[ "$selected_idx" =~ ^[0-9]+$ ]] && [ "$selected_idx" -gt 0 ] && [ "$selected_idx" -le "${#interfaces[@]}" ]; then
        vnc_ws_host=$(ip -4 -o addr show dev "${interfaces[$((selected_idx - 1))]}" scope global 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 | head -1)
        [ -n "$vnc_ws_host" ] && vnc_ws_host="${vnc_ws_host}:50055"
    else
        vnc_ws_host="127.0.0.1:50055"
    fi
    if [ -n "$vnc_ws_host" ]; then
        if grep -qE '^VNC_WS_HOST=' .env 2>/dev/null; then
            sed -i "s|^VNC_WS_HOST=.*|VNC_WS_HOST=${vnc_ws_host}|" .env
        else
            echo "VNC_WS_HOST=${vnc_ws_host}" >> .env
        fi
        install_log "VNC_WS_HOST=${vnc_ws_host} (VNC WebSocket via QemuControlService)"
        local vnc_ssl_cert_path="${SCRIPT_DIR}/docker/nginx/ssl/server.crt"
        local vnc_ssl_key_path="${SCRIPT_DIR}/docker/nginx/ssl/server.key"
        if [ -f "$vnc_ssl_cert_path" ] && [ -f "$vnc_ssl_key_path" ]; then
            if grep -qE '^VNC_SSL_CERT=' .env 2>/dev/null; then
                sed -i "s|^VNC_SSL_CERT=.*|VNC_SSL_CERT=${vnc_ssl_cert_path}|" .env
            else
                echo "VNC_SSL_CERT=${vnc_ssl_cert_path}" >> .env
            fi
            install_log "VNC_SSL_CERT=${vnc_ssl_cert_path} → websockify will use wss://"
        else
            if grep -qE '^VNC_SSL_CERT=' .env 2>/dev/null; then
                sed -i 's|^VNC_SSL_CERT=.*|VNC_SSL_CERT=|' .env
            fi
            install_log "VNC SSL cert not found — websockify will use ws://"
        fi
        if ! command -v websockify &>/dev/null; then
            if command -v apt-get &>/dev/null && sudo apt-get install -y websockify 2>/dev/null; then
                install_log "Installed websockify via apt"
            elif command -v pip3 &>/dev/null && sudo pip3 install websockify 2>/dev/null; then
                install_log "Installed websockify via pip3"
            elif command -v pip &>/dev/null && sudo pip install websockify 2>/dev/null; then
                install_log "Installed websockify via pip"
            else
                print_warning "websockify not found. Install: pip install websockify (or apt install websockify)"
            fi
        fi
        local vnc_token_file="${SCRIPT_DIR}/storage/app/vnc-tokens.txt"
        if [ -f /etc/QemuWebControl/qemu-control.conf ]; then
            if grep -qE '^VNC_TOKEN_FILE=' /etc/QemuWebControl/qemu-control.conf 2>/dev/null; then
                sudo sed -i "s|^VNC_TOKEN_FILE=.*|VNC_TOKEN_FILE=${vnc_token_file}|" /etc/QemuWebControl/qemu-control.conf
            else
                echo "VNC_TOKEN_FILE=${vnc_token_file}" | sudo tee -a /etc/QemuWebControl/qemu-control.conf > /dev/null
            fi
            install_log "VNC_TOKEN_FILE=${vnc_token_file}"
        fi
        if grep -qE '^VNC_PROXY_VIA_QEMU_CONTROL=' .env 2>/dev/null; then
            sed -i 's|^VNC_PROXY_VIA_QEMU_CONTROL=.*|VNC_PROXY_VIA_QEMU_CONTROL=true|' .env
        else
            echo "VNC_PROXY_VIA_QEMU_CONTROL=true" >> .env
        fi
        if command -v docker &>/dev/null && [ -f docker-compose.yml ] && docker compose ps -q app 2>/dev/null | grep -q .; then
            docker compose exec -T app php artisan config:clear 2>/dev/null || true
        fi
        local vnc_bind="0.0.0.0"
        if [ "$selected_idx" = "0" ] && ! grep -q "network_mode.*host" docker-compose.yml 2>/dev/null; then
            vnc_bind="0.0.0.0"
        elif [ "$selected_idx" = "0" ]; then
            vnc_bind="127.0.0.1"
        fi
        if [ -f /etc/QemuWebControl/qemu-control.conf ]; then
            if grep -qE '^VNC_BIND_ADDRESS=' /etc/QemuWebControl/qemu-control.conf 2>/dev/null; then
                sudo sed -i "s|^VNC_BIND_ADDRESS=.*|VNC_BIND_ADDRESS=${vnc_bind}|" /etc/QemuWebControl/qemu-control.conf
            else
                echo "VNC_BIND_ADDRESS=${vnc_bind}" | sudo tee -a /etc/QemuWebControl/qemu-control.conf > /dev/null
            fi
            install_log "VNC_BIND_ADDRESS=${vnc_bind} (QEMU VNC bind)"
        fi
    fi

    install_log "Access information:"
    install_log "HTTP:  $APP_URL"
    install_log "HTTPS: $APP_HTTPS"
    install_log "Administrator credentials:"
    install_log "${MESSAGES[admin_email]}"
    install_log "${MESSAGES[admin_password]}"
    install_log "Install log: $INSTALL_LOG"
    
    echo ""
    print_header
    format_line "${MESSAGES[installation_complete]}"
    echo "${MESSAGES[separator]}"
    format_line ""
    format_line "${MESSAGES[access_info]}"
    format_line "HTTP:  $APP_URL"
    format_line "HTTPS: $APP_HTTPS"
    format_line ""
    format_line "${MESSAGES[admin_credentials]}"
    format_line "${MESSAGES[admin_email]}"
    format_line "${MESSAGES[admin_password]}"
    format_line ""
    if [ -d "${SCRIPT_DIR}/services/QemuBootImagesControlService" ] && grep -qE '^BOOT_MEDIA_SERVICE_URL=' .env 2>/dev/null; then
        format_line "${MESSAGES[boot_media_hint]}"
        format_line ""
    fi
    format_line "Install log: $INSTALL_LOG"
    print_footer
}

NON_INTERACTIVE=false
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)
                [ -n "${2:-}" ] && set_language "$2" && shift 2 || shift
                ;;
            --non-interactive|-y)
                NON_INTERACTIVE=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    if [ "$NON_INTERACTIVE" = false ] && [ ! -t 0 ]; then
        NON_INTERACTIVE=true
        install_log "Stdin not a TTY, using non-interactive mode"
    fi
    if [ "$NON_INTERACTIVE" = false ]; then
        detect_language
    fi
    
    trap 'handle_exit $?' EXIT
    trap '_err=$?; install_log "ERR trap: line $LINENO | func=${FUNCNAME[*]} | cmd=$BASH_COMMAND | exit=$_err"; add_install_error "Command failed at line $LINENO in ${FUNCNAME[0]:-main}: $BASH_COMMAND (exit $_err)"; exit $_err' ERR
    load_messages
    check_sudo_privileges
    print_header
    
    install_log_section "Installation started"
    install_log "Log file: $INSTALL_LOG"
    install_log "Host: $(uname -n) | OS: $(uname -s) $(uname -r) | Arch: $(uname -m) | CPU cores: $(nproc 2>/dev/null || echo '?')"
    print_info "Installation log: $INSTALL_LOG"
    
    if [ -f .env ]; then
        safe_rm_f "${SCRIPT_DIR}/.env"
        install_log "Removed existing .env"
    fi
    if [ -f .env.example ]; then
        cp .env.example .env
        install_log "Created .env from .env.example"
    else
        log_fatal_error ".env.example not found. Cannot create .env file."
    fi
    
    install_log "--- check_architecture"
    check_architecture
    install_log "--- check_required_apt_packages"
    check_required_apt_packages
    install_log "--- check_docker"
    check_docker
    install_log "--- stop_existing_qemu_containers"
    stop_existing_qemu_containers
    install_log "--- setup_env"
    setup_env
    install_log "--- check_apache_port_conflict"
    check_apache_port_conflict
    install_log "--- setup_qemu_dirs"
    setup_qemu_dirs
    install_log "--- generate_ssl"
    generate_ssl
    install_log "--- setup_boot_images_service"
    setup_boot_images_service
    install_log "--- setup_qemu_control_service"
    setup_qemu_control_service
    install_log "--- configure_database"
    configure_database
    install_log "--- configure_db_firewall"
    configure_db_firewall
    install_log "--- run_installation"
    run_installation
    install_log "--- check_apache"
    check_apache
    install_log "--- configure_direct_web_firewall"
    configure_direct_web_firewall
    install_log "--- show_completion_message"
    show_completion_message
}

main "$@"
