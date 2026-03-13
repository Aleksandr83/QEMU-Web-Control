#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              QEMU Web Control - System Diagnostics                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_section() {
    echo ""
    echo -e "${CYAN}=== $1 ===${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. System Info
print_section "System Information"
echo "Hostname: $(hostname)"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"

# 2. Docker
print_section "Docker"
if command -v docker &> /dev/null; then
    print_ok "Docker installed: $(docker --version)"
    
    if sudo systemctl is-active --quiet docker; then
        print_ok "Docker service is running"
    else
        print_error "Docker service is NOT running"
        echo "  Fix: sudo systemctl start docker"
    fi
else
    print_error "Docker is NOT installed"
    echo "  Fix: ./install.sh"
fi

# 3. Docker Compose
print_section "Docker Compose"
if docker compose version &> /dev/null; then
    print_ok "Docker Compose (plugin): $(docker compose version)"
elif command -v docker-compose &> /dev/null; then
    print_ok "Docker Compose (standalone): $(docker-compose --version)"
else
    print_error "Docker Compose is NOT installed"
    echo "  Fix: sudo apt-get install docker-compose"
fi

# 4. Containers
print_section "Containers Status"
if [ -f docker-compose.yml ]; then
    COMPOSE_CMD="docker compose"
    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        fi
    fi
    
    $COMPOSE_CMD ps 2>/dev/null || print_error "Cannot get containers status"
else
    print_error "docker-compose.yml not found"
fi

# 5. Ports
print_section "Network Ports"
if command -v netstat &> /dev/null; then
    echo "Listening ports:"
    sudo netstat -tlnp 2>/dev/null | grep -E ':(80|443|8080|8443|3306)' || echo "No relevant ports found"
else
    print_warning "netstat not installed (optional)"
fi

# 6. Database
print_section "Database Connection"
if [ -f .env ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
    
    echo "Database: $DB_NAME @ $DB_HOST:$DB_PORT"
    
    if [ "$DB_HOST" = "db" ]; then
        # Docker database
        if $COMPOSE_CMD ps db 2>/dev/null | grep -q "Up"; then
            print_ok "Docker database container is running"
        else
            print_error "Docker database container is NOT running"
            echo "  Fix: docker compose up -d db"
        fi
    else
        # External database
        if command -v mysql &> /dev/null; then
            DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
            DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
            
            if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" &> /dev/null; then
                print_ok "External database connection successful"
            else
                print_error "Cannot connect to external database"
                echo "  Fix: Check DB credentials in .env"
            fi
        else
            print_warning "mysql client not installed - cannot test connection"
        fi
    fi
else
    print_error ".env file not found"
    echo "  Fix: cp .env.example .env"
fi

# 7. File Permissions
print_section "File Permissions"
check_permissions() {
    local dir=$1
    if [ -d "$dir" ]; then
        local owner=$(stat -c '%u:%g' "$dir" 2>/dev/null || stat -f '%u:%g' "$dir" 2>/dev/null)
        local perms=$(stat -c '%a' "$dir" 2>/dev/null || stat -f '%Lp' "$dir" 2>/dev/null)
        
        if [ "$owner" = "1000:1000" ] && [ "$perms" -ge "775" ]; then
            print_ok "$dir: $owner ($perms)"
        else
            print_warning "$dir: $owner ($perms) - should be 1000:1000 (775)"
            echo "  Fix: sudo chown -R 1000:1000 $dir && chmod -R 775 $dir"
        fi
    else
        print_error "$dir does not exist"
    fi
}

check_permissions "storage"
check_permissions "bootstrap/cache"
check_permissions "vendor"

# 8. Disk Space
print_section "Disk Space"
df -h . | tail -1 | awk '{
    used=$5+0
    if (used >= 90) 
        printf "\033[0;31m✗\033[0m %s used (Critical!)\n", $5
    else if (used >= 75)
        printf "\033[0;33m⚠\033[0m %s used (Warning)\n", $5
    else
        printf "\033[0;32m✓\033[0m %s used\n", $5
}'

# 9. Memory
print_section "Memory Usage"
free -h | grep Mem | awk '{
    used=$3
    total=$2
    printf "Used: %s / %s\n", used, total
}'

# 10. Application Status
print_section "Application Status"
if [ -f .env ]; then
    APP_PORT=$(grep APP_PORT .env | cut -d '=' -f2)
    APP_SSL_PORT=$(grep APP_SSL_PORT .env | cut -d '=' -f2)
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$APP_PORT 2>/dev/null | grep -q "200\|302"; then
        print_ok "HTTP application is responding on port $APP_PORT"
    else
        print_error "HTTP application is NOT responding on port $APP_PORT"
        echo "  Fix: docker compose logs nginx"
    fi
    
    if curl -s -k -o /dev/null -w "%{http_code}" https://localhost:$APP_SSL_PORT 2>/dev/null | grep -q "200\|302"; then
        print_ok "HTTPS application is responding on port $APP_SSL_PORT"
    else
        print_warning "HTTPS application is NOT responding on port $APP_SSL_PORT"
    fi
fi

# 11. Apache2 (if installed)
print_section "Apache2 (Optional)"
if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
    if sudo systemctl is-active --quiet apache2 2>/dev/null || sudo systemctl is-active --quiet httpd 2>/dev/null; then
        print_ok "Apache2 is installed and running"
        
        if [ -f /etc/apache2/sites-enabled/qemu-control.conf ]; then
            print_ok "QEMU Control site is enabled"
        else
            print_warning "QEMU Control site is NOT enabled"
            echo "  Fix: sudo a2ensite qemu-control.conf && sudo systemctl reload apache2"
        fi
    else
        print_warning "Apache2 is installed but NOT running"
    fi
else
    echo "Apache2 is not installed (optional)"
fi

# 12. Logs
print_section "Recent Errors (last 10 lines)"
if [ -f storage/logs/laravel.log ]; then
    echo "Laravel log:"
    tail -10 storage/logs/laravel.log | grep -i error || echo "  No recent errors"
else
    echo "No Laravel log file found"
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                           Diagnostic Complete                            ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "For detailed troubleshooting, see: docs/EN/TROUBLESHOOTING.EN.md / docs/RU/TROUBLESHOOTING.RU.md"
echo "To save this output: ./scripts/diagnose.sh > diagnosis.txt"
echo ""
