#!/bin/bash
# Safe remove: prevents deletion of critical Linux paths.
# Source this file and use safe_rm_rf / safe_rm_f instead of rm -rf / rm -f.

is_safe_to_remove() {
    local path="$1"
    [[ -z "$path" ]] && return 1
    path=$(realpath -m "$path" 2>/dev/null || echo "$path")
    path="${path%/}"
    [[ -z "$path" ]] && return 1
    [[ "$path" == "/" ]] && return 1

    case "$path" in
        /etc/apache2/sites-available/qemu-control.conf|/etc/apache2/sites-enabled/qemu-control.conf) return 0 ;;
        /etc/systemd/system/QemuBootImagesControlService.service) return 0 ;;
        /etc/systemd/system/QemuControlService.service) return 0 ;;
        /etc/systemd/system/qemu-autostart.service) return 0 ;;
        /etc/QemuWebControl/boot-media.conf) return 0 ;;
        /etc/QemuWebControl/qemu-control.conf) return 0 ;;
        /usr/local/bin/QemuBootImagesControlService) return 0 ;;
        /usr/local/bin/QemuControlService) return 0 ;;
        /var/log/QemuControlService.log) return 0 ;;
        /var/log/QemuBootImagesControlService.log) return 0 ;;
    esac

    [[ "$path" == /tmp || "$path" == /tmp/* ]] && return 0

    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        local script_dir="${SCRIPT_DIR%/}"
        [[ "$script_dir" == "/" ]] && return 1
        [[ "$(echo "$script_dir" | tr -cd '/' | wc -c)" -lt 2 ]] && return 1
        [[ "$path" == "$script_dir" || "$path" == "$script_dir"/* ]] && return 0
    fi

    [[ "$path" == /var/qemu || "$path" == /var/qemu/* ]] && return 0

    case "$path" in
        /bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*) return 1 ;;
        /etc|/etc/*|/usr|/usr/*|/var|/var/*) return 1 ;;
        /home|/home/*|/root|/root/*) return 1 ;;
        /boot|/boot/*|/opt|/opt/*) return 1 ;;
        /proc|/proc/*|/sys|/sys/*|/dev|/dev/*|/run|/run/*) return 1 ;;
        /mnt|/mnt/*|/media|/media/*|/srv|/srv/*) return 1 ;;
    esac

    return 0
}

safe_rm_rf() {
    local use_sudo=false
    [[ "${1:-}" == "--sudo" ]] && { use_sudo=true; shift; }
    local path
    for path in "$@"; do
        if is_safe_to_remove "$path"; then
            if $use_sudo; then
                rm -rf "$path" 2>/dev/null || sudo rm -rf "$path" 2>/dev/null || true
            else
                rm -rf "$path"
            fi
        else
            echo "ERROR: Refusing to remove critical path: $path" >&2
            return 1
        fi
    done
}

safe_rm_f() {
    local path
    for path in "$@"; do
        if is_safe_to_remove "$path"; then
            rm -f "$path"
        else
            echo "ERROR: Refusing to remove critical path: $path" >&2
            return 1
        fi
    done
}

safe_rm_f_sudo() {
    local path="$1"
    if is_safe_to_remove "$path"; then
        rm -f "$path" 2>/dev/null || sudo rm -f "$path" 2>/dev/null || true
    else
        echo "ERROR: Refusing to remove critical path: $path" >&2
        return 1
    fi
}

safe_rmdir_sudo() {
    local path="$1"
    if is_safe_to_remove "$path"; then
        rmdir "$path" 2>/dev/null || sudo rmdir "$path" 2>/dev/null || true
    else
        echo "ERROR: Refusing to remove critical path: $path" >&2
        return 1
    fi
}

