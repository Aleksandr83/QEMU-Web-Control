#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck source=scripts/safe-rm.sh
source "${SCRIPT_DIR}/scripts/safe-rm.sh"

LANG_CODE="en"
UNINSTALL_LOG="${SCRIPT_DIR}/uninstall-$(date +%Y%m%d-%H%M%S).log"

uninstall_log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$UNINSTALL_LOG"
}

uninstall_log_section() {
    echo "" >> "$UNINSTALL_LOG"
    echo "========== $1 ==========" >> "$UNINSTALL_LOG"
    uninstall_log "$1"
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
    ["warning"]="WARNING: This will remove the application and all its data!"
    ["confirm"]="Are you sure you want to uninstall? [yes/no]:"
    ["cancelled"]="Uninstallation cancelled"
    ["stopping"]="Stopping containers..."
    ["removing_containers"]="Removing containers..."
    ["removing_volumes"]="Removing volumes..."
    ["hdd_remove_prompt"]="Do you want to delete VM disk files (HDD)? [y/n]:"
    ["hdd_remove_skipped"]="VM disk files kept"
    ["hdd_removing"]="Removing VM disk files..."
    ["hdd_removed"]="VM disk files removed"
    ["hdd_none_found"]="No disk paths found in database"
    ["db_remove_prompt"]="Do you want to remove the application database? [y/n]:"
    ["db_remove_skipped"]="Database removal skipped"
    ["db_removing_external"]="Removing database from external MariaDB/MySQL..."
    ["db_removed_external"]="External database removed successfully"
    ["db_remove_external_failed"]="Failed to remove external database automatically"
    ["db_removing_docker"]="Removing Docker database volume..."
    ["db_removed_docker"]="Docker database volume removed"
    ["mysql_not_found"]="mysql client not found, cannot remove external database automatically"
    ["removing_images"]="Removing images..."
    ["removing_files"]="Removing project files..."
    ["apache_conf_found"]="Apache config qemu-control.conf was found:"
    ["apache_conf_remove_prompt"]="Do you want to remove these Apache config files? [y/n]:"
    ["apache_conf_removed"]="Apache config files removed"
    ["apache_conf_kept"]="Apache config files were kept"
    ["complete"]="Uninstallation completed successfully"
    ["keeping_files"]="Project files kept (use --clean to remove)"
    ["boot_service_remove"]="Removing QemuBootImagesControlService..."
    ["boot_service_removed"]="QemuBootImagesControlService removed"
    ["qemu_control_service_remove"]="Removing QemuControlService..."
    ["qemu_control_service_removed"]="QemuControlService removed"
    ["checking_sudo"]="Checking sudo privileges..."
    ["sudo_required"]="Sudo privileges are required. Run as a sudo-enabled user or as root."
)

declare -A MESSAGES_RU=(
    ["warning"]="ВНИМАНИЕ: Это удалит приложение и все его данные!"
    ["confirm"]="Вы уверены, что хотите удалить? [yes/no]:"
    ["cancelled"]="Удаление отменено"
    ["stopping"]="Остановка контейнеров..."
    ["removing_containers"]="Удаление контейнеров..."
    ["removing_volumes"]="Удаление томов..."
    ["hdd_remove_prompt"]="Удалить файлы дисков ВМ (HDD)? [y/n]:"
    ["hdd_remove_skipped"]="Файлы дисков ВМ сохранены"
    ["hdd_removing"]="Удаление файлов дисков ВМ..."
    ["hdd_removed"]="Файлы дисков ВМ удалены"
    ["hdd_none_found"]="Пути к дискам в базе не найдены"
    ["db_remove_prompt"]="Удалить базу данных приложения? [y/n]:"
    ["db_remove_skipped"]="Удаление базы данных пропущено"
    ["db_removing_external"]="Удаление базы из внешней MariaDB/MySQL..."
    ["db_removed_external"]="Внешняя база данных успешно удалена"
    ["db_remove_external_failed"]="Не удалось автоматически удалить внешнюю базу данных"
    ["db_removing_docker"]="Удаление Docker volume с базой..."
    ["db_removed_docker"]="Docker volume базы данных удален"
    ["mysql_not_found"]="mysql-клиент не найден, внешнюю базу автоматически удалить нельзя"
    ["removing_images"]="Удаление образов..."
    ["removing_files"]="Удаление файлов проекта..."
    ["apache_conf_found"]="Найдены Apache-конфиги qemu-control.conf:"
    ["apache_conf_remove_prompt"]="Удалить эти файлы конфигурации Apache? [y/n]:"
    ["apache_conf_removed"]="Apache-конфиги удалены"
    ["apache_conf_kept"]="Apache-конфиги сохранены"
    ["complete"]="Удаление успешно завершено"
    ["keeping_files"]="Файлы проекта сохранены (используйте --clean для удаления)"
    ["boot_service_remove"]="Удаление QemuBootImagesControlService..."
    ["boot_service_removed"]="QemuBootImagesControlService удалён"
    ["qemu_control_service_remove"]="Удаление QemuControlService..."
    ["qemu_control_service_removed"]="QemuControlService удалён"
    ["checking_sudo"]="Проверка sudo-привилегий..."
    ["sudo_required"]="Требуются sudo-привилегии. Запустите от пользователя с sudo или от root."
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

check_sudo_privileges() {
    print_info "${MESSAGES[checking_sudo]}"
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        uninstall_log "Running as root, sudo check skipped"
        return 0
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        print_error "${MESSAGES[sudo_required]}"
        uninstall_log "ERROR: sudo not found"
        exit 1
    fi
    if ! sudo -v 2>/dev/null; then
        print_error "${MESSAGES[sudo_required]}"
        uninstall_log "ERROR: sudo -v failed"
        exit 1
    fi
    uninstall_log "Sudo privileges OK"
}

uninstall() {
    local clean_files=false
    
    if [[ "$1" == "--clean" ]]; then
        clean_files=true
    fi

    uninstall_log_section "Uninstall started"
    uninstall_log "Log file: $UNINSTALL_LOG"
    uninstall_log "Mode: clean_files=$clean_files"

    check_sudo_privileges

    print_warning "${MESSAGES[warning]}"
    echo ""
    read -p "${MESSAGES[confirm]} " confirm
    
    if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "${MESSAGES[cancelled]}"
        uninstall_log "Uninstall cancelled by user"
        exit 0
    fi

    local db_host db_port db_name db_user db_pass db_root_pass
    db_host=$(grep '^DB_HOST=' .env 2>/dev/null | cut -d '=' -f2)
    db_port=$(grep '^DB_PORT=' .env 2>/dev/null | cut -d '=' -f2)
    db_name=$(grep '^DB_DATABASE=' .env 2>/dev/null | cut -d '=' -f2)
    db_user=$(grep '^DB_USERNAME=' .env 2>/dev/null | cut -d '=' -f2)
    db_pass=$(grep '^DB_PASSWORD=' .env 2>/dev/null | cut -d '=' -f2)
    db_root_pass=$(grep '^DB_ROOT_PASSWORD=' .env 2>/dev/null | cut -d '=' -f2)
    db_port=${db_port:-3306}
    db_name=${db_name:-qemu-control}

    local remove_hdd=false
    local disk_paths=()
    if [ "$db_host" = "db" ]; then
        local compose_cmd_pre="docker compose"
        command -v docker-compose &>/dev/null && compose_cmd_pre="docker-compose"
        while IFS= read -r line; do
            [ -n "$line" ] && disk_paths+=("$line")
        done < <($compose_cmd_pre exec -T db mysql -u "${db_user:-root}" -p"${db_pass:-$db_root_pass}" "$db_name" -N -e "SELECT path FROM virtual_machine_disks" 2>/dev/null || true)
        if [ ${#disk_paths[@]} -eq 0 ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && disk_paths+=("$line")
            done < <($compose_cmd_pre exec -T db mysql -u "${db_user:-root}" -p"${db_pass:-$db_root_pass}" "$db_name" -N -e "SELECT disk_path FROM virtual_machines WHERE disk_path IS NOT NULL" 2>/dev/null || true)
        fi
    elif command -v mysql &>/dev/null 2>&1; then
        local mysql_auth=""
        [ -n "$db_root_pass" ] && mysql_auth="-u root -p$db_root_pass"
        [ -z "$mysql_auth" ] && [ -n "$db_user" ] && [ -n "$db_pass" ] && mysql_auth="-u $db_user -p$db_pass"
        if [ -n "$mysql_auth" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && disk_paths+=("$line")
            done < <(mysql -h "${db_host:-127.0.0.1}" -P "$db_port" $mysql_auth "$db_name" -N -e "SELECT path FROM virtual_machine_disks" 2>/dev/null || true)
            if [ ${#disk_paths[@]} -eq 0 ]; then
                while IFS= read -r line; do
                    [ -n "$line" ] && disk_paths+=("$line")
                done < <(mysql -h "${db_host:-127.0.0.1}" -P "$db_port" $mysql_auth "$db_name" -N -e "SELECT disk_path FROM virtual_machines WHERE disk_path IS NOT NULL" 2>/dev/null || true)
            fi
        fi
    fi

    if [ ${#disk_paths[@]} -gt 0 ]; then
        read -p "${MESSAGES[hdd_remove_prompt]} " remove_hdd_answer
        if [[ "$remove_hdd_answer" =~ ^[Yy]$ ]]; then
            remove_hdd=true
        fi
        uninstall_log "HDD removal requested: $remove_hdd"
    else
        print_info "${MESSAGES[hdd_none_found]}"
        uninstall_log "No disk paths found in database"
    fi

    if [ "$remove_hdd" = true ]; then
        print_info "${MESSAGES[hdd_removing]}"
        local path
        for path in "${disk_paths[@]}"; do
            path=$(echo "$path" | tr -d '\r')
            if [ -f "$path" ]; then
                safe_rm_f_sudo "$path"
                uninstall_log "Removed disk file: $path"
            fi
            local disk_dir=$(dirname "$path")
            if [ -d "$disk_dir" ] && [ -z "$(ls -A "$disk_dir" 2>/dev/null)" ]; then
                safe_rmdir_sudo "$disk_dir"
            fi
        done
        print_success "${MESSAGES[hdd_removed]}"
        uninstall_log "HDD files removed: ${#disk_paths[@]} paths"
    else
        print_info "${MESSAGES[hdd_remove_skipped]}"
        uninstall_log "HDD removal skipped"
    fi

    echo ""
    
    # Определяем команду docker compose
    local compose_cmd="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
    fi
    uninstall_log "Using compose command: $compose_cmd"
    
    echo ""
    print_info "${MESSAGES[stopping]}"
    $compose_cmd down 2>/dev/null || true
    uninstall_log "Containers stopped via $compose_cmd down"

    print_info "${MESSAGES[removing_containers]}"
    COMPOSE_PROJECT=$(grep COMPOSE_PROJECT_NAME .env 2>/dev/null | cut -d '=' -f2 || echo "qemu")
    docker ps -a -q --filter "name=${COMPOSE_PROJECT}_" 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    docker rm -f "${COMPOSE_PROJECT}_app" "${COMPOSE_PROJECT}_nginx" "${COMPOSE_PROJECT}_db" "${COMPOSE_PROJECT}_scheduler" 2>/dev/null || true
    uninstall_log "Containers removed for project: $COMPOSE_PROJECT"

    local remove_db=false
    read -p "${MESSAGES[db_remove_prompt]} " remove_db_answer
    if [[ "$remove_db_answer" =~ ^[Yy]$ ]]; then
        remove_db=true
    fi
    uninstall_log "Database removal requested: $remove_db (DB_HOST=${db_host:-unset}, DB_NAME=${db_name:-unset})"

    if [ "$remove_db" = true ]; then
        if [ "$db_host" = "db" ]; then
            print_info "${MESSAGES[db_removing_docker]}"
            print_info "${MESSAGES[removing_volumes]}"
            docker volume rm "${COMPOSE_PROJECT}_dbdata" 2>/dev/null || true
            print_success "${MESSAGES[db_removed_docker]}"
            uninstall_log "Docker DB volume removed: ${COMPOSE_PROJECT}_dbdata"
        else
            print_info "${MESSAGES[db_removing_external]}"
            if ! command -v mysql >/dev/null 2>&1; then
                print_warning "${MESSAGES[mysql_not_found]}"
            else
                local mysql_drop_sql="DROP DATABASE IF EXISTS \`$db_name\`;"
                local db_removed=false

                if [ -n "$db_root_pass" ] && mysql -h "${db_host:-127.0.0.1}" -P "$db_port" -u root -p"$db_root_pass" -e "$mysql_drop_sql" 2>/dev/null; then
                    db_removed=true
                elif [ -n "$db_user" ] && [ -n "$db_pass" ] && mysql -h "${db_host:-127.0.0.1}" -P "$db_port" -u "$db_user" -p"$db_pass" -e "$mysql_drop_sql" 2>/dev/null; then
                    db_removed=true
                else
                    read -sp "Enter DB admin password to drop '${db_name}' [skip=empty]: " manual_db_pass
                    echo ""
                    if [ -n "$manual_db_pass" ] && mysql -h "${db_host:-127.0.0.1}" -P "$db_port" -u root -p"$manual_db_pass" -e "$mysql_drop_sql" 2>/dev/null; then
                        db_removed=true
                    fi
                fi

                if [ "$db_removed" = true ]; then
                    print_success "${MESSAGES[db_removed_external]}"
                    uninstall_log "External DB dropped: $db_name at ${db_host:-127.0.0.1}:$db_port"
                else
                    print_warning "${MESSAGES[db_remove_external_failed]}"
                    print_warning "Drop manually: DROP DATABASE IF EXISTS \`$db_name\`;"
                    uninstall_log "External DB drop failed: $db_name at ${db_host:-127.0.0.1}:$db_port"
                fi
            fi
        fi
    else
        print_info "${MESSAGES[db_remove_skipped]}"
        uninstall_log "Database removal skipped"
    fi
    
    print_info "${MESSAGES[removing_images]}"
    docker rmi "${COMPOSE_PROJECT}_app" 2>/dev/null || true
    uninstall_log "Images removal attempted for project: $COMPOSE_PROJECT"

    if [ -d /etc/apache2 ]; then
        local apache_files=()
        [ -f /etc/apache2/sites-available/qemu-control.conf ] && apache_files+=("/etc/apache2/sites-available/qemu-control.conf")
        [ -f /etc/apache2/sites-enabled/qemu-control.conf ] && apache_files+=("/etc/apache2/sites-enabled/qemu-control.conf")

        if [ ${#apache_files[@]} -gt 0 ]; then
            echo ""
            print_warning "${MESSAGES[apache_conf_found]}"
            local apache_file
            for apache_file in "${apache_files[@]}"; do
                echo "  - $apache_file"
            done
            echo ""
            read -p "${MESSAGES[apache_conf_remove_prompt]} " remove_apache_conf
            if [[ "$remove_apache_conf" =~ ^[Yy]$ ]]; then
                for apache_file in "${apache_files[@]}"; do
                    safe_rm_f_sudo "$apache_file"
                done
                print_success "${MESSAGES[apache_conf_removed]}"
                uninstall_log "Apache config files removed: ${apache_files[*]}"
            else
                print_info "${MESSAGES[apache_conf_kept]}"
                uninstall_log "Apache config files kept: ${apache_files[*]}"
            fi
        fi
    fi

    if [ -f /usr/local/bin/QemuBootImagesControlService ]; then
        print_info "${MESSAGES[boot_service_remove]}"
        sudo systemctl stop QemuBootImagesControlService.service 2>/dev/null || true
        sudo systemctl disable QemuBootImagesControlService.service 2>/dev/null || true
        [ -f /etc/systemd/system/QemuBootImagesControlService.service ] && safe_rm_f_sudo /etc/systemd/system/QemuBootImagesControlService.service
        sudo systemctl daemon-reload 2>/dev/null || true
        safe_rm_f_sudo /usr/local/bin/QemuBootImagesControlService
        [ -f /etc/QemuWebControl/boot-media.conf ] && safe_rm_f_sudo /etc/QemuWebControl/boot-media.conf
        print_success "${MESSAGES[boot_service_removed]}"
        uninstall_log "QemuBootImagesControlService and boot-media.conf removed"
    fi

    if [ -f /usr/local/bin/QemuControlService ]; then
        print_info "${MESSAGES[qemu_control_service_remove]}"
        sudo systemctl stop QemuControlService.service 2>/dev/null || true
        sudo systemctl disable QemuControlService.service 2>/dev/null || true
        [ -f /etc/systemd/system/QemuControlService.service ] && safe_rm_f_sudo /etc/systemd/system/QemuControlService.service
        sudo systemctl daemon-reload 2>/dev/null || true
        safe_rm_f_sudo /usr/local/bin/QemuControlService
        [ -f /etc/QemuWebControl/qemu-control.conf ] && safe_rm_f_sudo /etc/QemuWebControl/qemu-control.conf
        print_success "${MESSAGES[qemu_control_service_removed]}"
        uninstall_log "QemuControlService and qemu-control.conf removed"
    fi
    
    uninstall_log_section "Uninstall completed successfully"
    uninstall_log "Log saved to: $UNINSTALL_LOG"

    if [ "$clean_files" = true ]; then
        print_info "${MESSAGES[removing_files]}"
        cd ..
        uninstall_log "Project directory removed: $SCRIPT_DIR"
        safe_rm_rf "$SCRIPT_DIR"
        print_success "${MESSAGES[complete]}"
    else
        print_info "${MESSAGES[keeping_files]}"
        safe_rm_rf "${SCRIPT_DIR}/vendor" "${SCRIPT_DIR}/node_modules" 2>/dev/null || true
        safe_rm_f "${SCRIPT_DIR}/.env" 2>/dev/null || true
        safe_rm_rf "${SCRIPT_DIR}/storage/logs" "${SCRIPT_DIR}/bootstrap/cache" 2>/dev/null || true
        uninstall_log "Project files kept, runtime artifacts removed"
        print_success "${MESSAGES[complete]}"

        echo ""
        print_info "Uninstall log: $UNINSTALL_LOG"
    fi
}

main() {
    local clean_arg=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lang)
                set_language "$2"
                shift 2
                ;;
            --clean)
                clean_arg="--clean"
                shift
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
    uninstall "$clean_arg"
}

main "$@"
