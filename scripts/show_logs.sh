#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

LINES="${LINES:-50}"

usage() {
    echo "Usage: $0 [OPTIONS] [TYPE]"
    echo ""
    echo "Show application logs. Output is always saved to a file."
    echo ""
    echo "TYPE:"
    echo "  vnc      - VNC console opens (Laravel)"
    echo "  qemu-control - QemuControlService log (host)"
    echo "  laravel  - Laravel log (last $LINES lines)"
    echo "  app      - Docker app container (php-fpm)"
    echo "  all      - All of the above (default)"
    echo ""
    echo "OPTIONS:"
    echo "  -n N     - Number of lines (default: $LINES)"
    echo "  -f       - Follow (tail -f)"
    echo "  -o FILE  - Output file (default: show_logs_YYYYMMDD-HHMMSS.log)"
    echo ""
    echo "Examples:"
    echo "  $0              # all logs, auto filename"
    echo "  $0 vnc"
    echo "  $0 -n 100 -o my.log"
}

FOLLOW=""
OUTPUT_FILE=""
while getopts "fn:o:h" opt; do
    case $opt in
        n) LINES="$OPTARG" ;;
        f) FOLLOW="-f" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

TYPE="${1:-all}"

if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="show_logs_$(date +%Y%m%d-%H%M%S).log"
fi

show_vnc() {
    echo "=== VNC console opens (Laravel) ==="
    if [ -n "$FOLLOW" ]; then
        docker compose exec -T app tail -f storage/logs/laravel.log 2>/dev/null | grep --line-buffered "VNC console opened" || true
    else
        docker compose exec -T app tail -n "$LINES" storage/logs/laravel.log 2>/dev/null | grep "VNC console opened" || echo "No VNC entries found."
    fi
}

show_qemu_control() {
    echo "=== QemuControlService log (host) ==="
    if [ -f /var/log/QemuControlService.log ]; then
        if [ -n "$FOLLOW" ]; then
            sudo tail -f /var/log/QemuControlService.log 2>/dev/null || tail -f /var/log/QemuControlService.log 2>/dev/null || echo "Cannot read log."
        else
            sudo tail -n "$LINES" /var/log/QemuControlService.log 2>/dev/null || tail -n "$LINES" /var/log/QemuControlService.log 2>/dev/null || echo "Cannot read log."
        fi
    else
        echo "QemuControlService.log not found."
    fi
}

show_laravel() {
    echo "=== Laravel log (last $LINES lines) ==="
    if [ -n "$FOLLOW" ]; then
        docker compose exec -T app tail -f storage/logs/laravel.log 2>/dev/null || echo "Laravel log not found."
    else
        docker compose exec -T app tail -n "$LINES" storage/logs/laravel.log 2>/dev/null || echo "Laravel log not found."
    fi
}

show_app() {
    echo "=== App container (websockify, php-fpm) ==="
    if [ -n "$FOLLOW" ]; then
        docker compose logs -f app 2>&1
    else
        docker compose logs --tail "$LINES" app 2>&1
    fi
}

do_show() {
    case "$TYPE" in
        vnc)    show_vnc ;;
        qemu-control) show_qemu_control ;;
        laravel) show_laravel ;;
        app)    show_app ;;
        all)
            show_vnc
            echo ""
            show_qemu_control
            echo ""
            show_laravel
            echo ""
            show_app
            ;;
        *)
            echo "Unknown type: $TYPE"
            usage
            exit 1
            ;;
    esac
}

echo "=== $(date -Iseconds) ===" >> "$OUTPUT_FILE"
do_show 2>&1 | tee -a "$OUTPUT_FILE"
echo ""
echo "Saved to $OUTPUT_FILE"
