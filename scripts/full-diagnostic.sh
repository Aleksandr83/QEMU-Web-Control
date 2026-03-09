#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║            QEMU Web Control - Full Diagnostic Report                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}➜${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_section() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

LOG_FILE="diagnostic-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "  $1" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

run_cmd() {
    local desc="$1"
    local cmd="$2"
    
    echo "→ $desc" | tee -a "$LOG_FILE"
    echo "  Command: $cmd" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}
    
    echo "" >> "$LOG_FILE"
    echo "  Exit code: $exit_code" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    return $exit_code
}

print_section "Starting Full Diagnostic"
log_section "QEMU Web Control - Diagnostic Report"
log "Date: $(date)"
log "Hostname: $(hostname)"
log ""

# 1. Системная информация
log_section "1. SYSTEM INFORMATION"

run_cmd "Architecture" "uname -m"
run_cmd "Kernel version" "uname -r"
run_cmd "OS information" "cat /etc/os-release"
run_cmd "CPU info" "lscpu | head -20"
run_cmd "Memory info" "free -h"
run_cmd "Disk space" "df -h ."

# 2. Docker информация
log_section "2. DOCKER INFORMATION"

if command -v docker &> /dev/null; then
    print_success "Docker installed"
    run_cmd "Docker version" "docker --version"
    run_cmd "Docker info" "docker info"
    run_cmd "Docker compose version" "docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'Docker Compose not found'"
else
    print_error "Docker not installed"
    log "✗ Docker not installed"
fi

# 3. Файлы проекта
log_section "3. PROJECT FILES"

run_cmd "Current directory" "pwd"
run_cmd "Project files" "ls -lah"
run_cmd "Docker compose files" "ls -lah docker-compose*.yml 2>/dev/null || echo 'No docker-compose files found'"
run_cmd "Environment file" "ls -lah .env* 2>/dev/null || echo 'No .env files found'"

# 4. Конфигурация .env
log_section "4. ENVIRONMENT CONFIGURATION"

if [ -f .env ]; then
    print_success ".env file exists"
    log "✓ .env file exists"
    echo "" >> "$LOG_FILE"
    
    # Показываем важные параметры (без паролей)
    echo "Key configuration:" | tee -a "$LOG_FILE"
    grep -E "^(APP_|DB_|COMPOSE_)" .env | grep -v PASSWORD | tee -a "$LOG_FILE"
    
    echo "" >> "$LOG_FILE"
    echo "Database configuration:" | tee -a "$LOG_FILE"
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
    
    log "  DB_HOST: $DB_HOST"
    log "  DB_PORT: $DB_PORT"
    log "  DB_NAME: $DB_NAME"
    log "  DB_USER: $DB_USER"
else
    print_error ".env file not found"
    log "✗ .env file not found"
fi

# 5. Docker Compose конфигурация
log_section "5. DOCKER COMPOSE CONFIGURATION"

if [ -f docker-compose.yml ]; then
    print_success "docker-compose.yml exists"
    log "✓ docker-compose.yml exists"
    echo "" >> "$LOG_FILE"
    
    # Проверяем наличие db сервиса
    if grep -q "^  db:" docker-compose.yml; then
        print_warning "Found 'db' service in docker-compose.yml"
        log "⚠ Found 'db' service in docker-compose.yml"
        log "  This will cause problems on RISC-V!"
        
        # Показываем db секцию
        echo "" >> "$LOG_FILE"
        echo "DB service configuration:" >> "$LOG_FILE"
        sed -n '/^  db:/,/^  [a-z]/p' docker-compose.yml | head -n -1 >> "$LOG_FILE"
    else
        print_success "No 'db' service in docker-compose.yml (good for RISC-V)"
        log "✓ No 'db' service in docker-compose.yml"
    fi
    
    # Показываем список сервисов
    echo "" >> "$LOG_FILE"
    echo "Services defined:" >> "$LOG_FILE"
    grep "^  [a-z]" docker-compose.yml | sed 's/:$//' >> "$LOG_FILE"
else
    print_error "docker-compose.yml not found"
    log "✗ docker-compose.yml not found"
fi

# Проверяем наличие RISC-V версии
if [ -f docker/docker-compose.riscv.yml ]; then
    print_success "docker/docker-compose.riscv.yml exists"
    log "✓ docker/docker-compose.riscv.yml exists"
else
    print_warning "docker/docker-compose.riscv.yml not found"
    log "⚠ docker/docker-compose.riscv.yml not found"
fi

# 6. Docker контейнеры
log_section "6. DOCKER CONTAINERS"

if command -v docker &> /dev/null; then
    run_cmd "Running containers" "docker compose ps"
    run_cmd "All containers (including stopped)" "docker compose ps -a"
    run_cmd "Docker images" "docker images | grep -E '(REPOSITORY|qemu)'"
    
    # Логи контейнеров
    echo "" | tee -a "$LOG_FILE"
    echo "Container logs (last 50 lines each):" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    for container in $(docker compose ps -q 2>/dev/null); do
        container_name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
        echo "--- Logs for $container_name ---" | tee -a "$LOG_FILE"
        docker logs --tail 50 $container 2>&1 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    done
fi

# 7. База данных
log_section "7. DATABASE CONNECTION"

if [ -f .env ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    
    # Проверяем MySQL клиент
    if command -v mysql &> /dev/null; then
        print_success "MySQL client installed"
        log "✓ MySQL client installed"
        
        # Проверяем подключение к серверу
        echo "" | tee -a "$LOG_FILE"
        echo "Testing database connection to $DB_HOST:$DB_PORT..." | tee -a "$LOG_FILE"
        
        if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>/dev/null; then
            print_success "Database connection OK"
            log "✓ Database connection successful"
            
            # Проверяем существование БД
            if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
                print_success "Database '$DB_NAME' exists"
                log "✓ Database '$DB_NAME' exists"
                
                # Показываем таблицы
                echo "" >> "$LOG_FILE"
                echo "Tables in database:" >> "$LOG_FILE"
                mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SHOW TABLES" "$DB_NAME" 2>/dev/null | tee -a "$LOG_FILE"
                
                # Проверяем миграции
                MIGRATION_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT COUNT(*) FROM migrations" "$DB_NAME" -N 2>/dev/null)
                if [ -n "$MIGRATION_COUNT" ]; then
                    log ""
                    log "Migrations run: $MIGRATION_COUNT"
                fi
            else
                print_error "Database '$DB_NAME' does not exist"
                log "✗ Database '$DB_NAME' does not exist"
            fi
        else
            print_error "Cannot connect to database"
            log "✗ Cannot connect to database at $DB_HOST:$DB_PORT"
            
            # Пробуем показать ошибку
            echo "" >> "$LOG_FILE"
            echo "Connection error details:" >> "$LOG_FILE"
            mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        print_warning "MySQL client not installed"
        log "⚠ MySQL client not installed"
    fi
    
    # Проверяем MySQL сервер
    echo "" | tee -a "$LOG_FILE"
    if systemctl is-active --quiet mariadb 2>/dev/null; then
        print_success "MariaDB service is running"
        log "✓ MariaDB service is running"
    elif systemctl is-active --quiet mysql 2>/dev/null; then
        print_success "MySQL service is running"
        log "✓ MySQL service is running"
    else
        print_warning "MariaDB/MySQL service not running or not installed"
        log "⚠ MariaDB/MySQL service not running"
    fi
fi

# 8. Сетевая информация
log_section "8. NETWORK INFORMATION"

run_cmd "Network interfaces" "ip addr show"
run_cmd "Listening ports" "ss -tlnp | grep -E '(8080|8443|3306|9000)' || netstat -tlnp | grep -E '(8080|8443|3306|9000)' || echo 'No ports found'"
run_cmd "Docker networks" "docker network ls"

# 9. Проверка файлов Docker
log_section "9. DOCKER FILES"

if [ -d docker ]; then
    run_cmd "Docker directory structure" "find docker -type f"
    
    # Проверяем Dockerfile
    if [ -f docker/php/Dockerfile ]; then
        echo "" >> "$LOG_FILE"
        echo "PHP Dockerfile (first 30 lines):" >> "$LOG_FILE"
        head -30 docker/php/Dockerfile >> "$LOG_FILE"
    fi
    
    # Проверяем Nginx конфиг
    if [ -f docker/nginx/conf.d/default.conf ]; then
        echo "" >> "$LOG_FILE"
        echo "Nginx configuration:" >> "$LOG_FILE"
        cat docker/nginx/conf.d/default.conf >> "$LOG_FILE"
    fi
fi

# 10. Проверка скриптов
log_section "10. AVAILABLE SCRIPTS"

run_cmd "Executable scripts" "ls -lah *.sh 2>/dev/null || echo 'No .sh files found'"

# 11. Проверка прав доступа
log_section "11. PERMISSIONS"

run_cmd "Storage permissions" "ls -lah storage/ 2>/dev/null || echo 'storage/ not found'"
run_cmd "Bootstrap cache permissions" "ls -lah bootstrap/cache/ 2>/dev/null || echo 'bootstrap/cache/ not found'"

# 12. Последние ошибки из логов
log_section "12. RECENT ERRORS"

if [ -f storage/logs/laravel.log ]; then
    echo "Last 30 lines from Laravel log:" | tee -a "$LOG_FILE"
    tail -30 storage/logs/laravel.log | tee -a "$LOG_FILE"
else
    log "No Laravel log file found"
fi

# 13. Диагностика проблем
log_section "13. PROBLEM DIAGNOSIS"

ARCH=$(uname -m)
PROBLEMS_FOUND=0

log "Architecture: $ARCH"
log ""

# Проблема 1: RISC-V + db в docker-compose
if [ "$ARCH" = "riscv64" ] && [ -f docker-compose.yml ] && grep -q "^  db:" docker-compose.yml; then
    print_error "PROBLEM: RISC-V with 'db' service in docker-compose.yml"
    log "✗ PROBLEM: RISC-V with 'db' service in docker-compose.yml"
    log "  MariaDB Docker image is not available for RISC-V"
    log "  SOLUTION: Run ./scripts/fix-database-riscv.sh"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

# Проблема 2: DB_HOST=db на RISC-V
if [ "$ARCH" = "riscv64" ] && [ -f .env ]; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    if [ "$DB_HOST" = "db" ]; then
        print_error "PROBLEM: DB_HOST=db on RISC-V"
        log "✗ PROBLEM: DB_HOST=db on RISC-V"
        log "  Cannot use Docker database on RISC-V"
        log "  SOLUTION: Change DB_HOST to 'localhost' and run ./scripts/setup-database.sh"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
fi

# Проблема 3: .env не существует
if [ ! -f .env ]; then
    print_error "PROBLEM: .env file not found"
    log "✗ PROBLEM: .env file not found"
    log "  SOLUTION: cp .env.example .env"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

# Проблема 4: База данных не существует
if [ -f .env ] && command -v mysql &> /dev/null; then
    DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
    
    if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
        print_error "PROBLEM: Database does not exist or cannot connect"
        log "✗ PROBLEM: Database does not exist or cannot connect"
        log "  SOLUTION: Run ./scripts/setup-database.sh"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
fi

# Проблема 5: Контейнеры не запущены
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker compose ps -q 2>/dev/null | wc -l)
    if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
        print_error "PROBLEM: No containers running"
        log "✗ PROBLEM: No containers running"
        log "  SOLUTION: docker compose up -d"
        PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
    fi
fi

log ""
if [ $PROBLEMS_FOUND -eq 0 ]; then
    print_success "No obvious problems found"
    log "✓ No obvious problems found"
else
    print_warning "Found $PROBLEMS_FOUND problem(s)"
    log "⚠ Found $PROBLEMS_FOUND problem(s)"
fi

# 14. Рекомендации
log_section "14. RECOMMENDATIONS"

if [ "$ARCH" = "riscv64" ]; then
    log "For RISC-V (Orange Pi, VisionFive):"
    log ""
    log "1. Use external MariaDB:"
    log "   ./scripts/fix-database-riscv.sh"
    log ""
    log "2. Use simplified Node.js Dockerfile:"
    log "   ./scripts/fix-nodejs-riscv.sh"
    log ""
    log "3. Quick fix after failed installation:"
    log "   ./scripts/quick-fix-riscv.sh"
    log ""
fi

log "Common solutions:"
log ""
log "- Setup database:        ./scripts/setup-database.sh"
log "- Full diagnostic:       ./scripts/diagnose.sh"
log "- View logs:             docker compose logs -f"
log "- Restart containers:    docker compose restart"
log "- Rebuild containers:    docker compose build --no-cache"
log ""

# Финал
log_section "DIAGNOSTIC COMPLETE"

print_success "Diagnostic report saved to: $LOG_FILE"
log "Report saved to: $LOG_FILE"
log ""
log "To share this report:"
log "  cat $LOG_FILE"
log ""
log "To compress for sharing:"
log "  tar -czf diagnostic.tar.gz $LOG_FILE"
log ""

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}✓${NC} Diagnostic complete!"
echo -e "${CYAN}➜${NC} Report saved to: ${YELLOW}$LOG_FILE${NC}"
echo ""
echo "To view the report:"
echo "  cat $LOG_FILE"
echo ""
echo "To share the report:"
echo "  cat $LOG_FILE | curl -F 'file=@-' https://0x0.st"
echo ""
