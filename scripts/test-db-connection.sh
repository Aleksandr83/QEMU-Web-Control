#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              Quick Database Connection Test & Fix                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}➜${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Читаем .env
if [ ! -f .env ]; then
    print_error ".env not found!"
    exit 1
fi

DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)

echo "Configuration:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo ""

# Шаг 1: Проверка с хоста
print_info "Step 1: Testing from host..."
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    print_success "Host can connect"
else
    print_error "Host cannot connect"
    echo ""
    echo "Fix MariaDB first:"
    echo "  sudo systemctl start mariadb"
    echo "  ./scripts/setup-database.sh"
    exit 1
fi

# Шаг 2: Проверка контейнеров
print_info "Step 2: Checking containers..."
if ! docker compose ps | grep -q "app.*Up"; then
    print_warning "Containers not running, starting..."
    docker compose down 2>/dev/null
    docker compose up -d
    
    echo "Waiting 10 seconds for containers to start..."
    sleep 10
fi

if docker compose ps | grep -q "app.*Up"; then
    print_success "Containers are running"
else
    print_error "Containers failed to start"
    docker compose ps
    exit 1
fi

# Шаг 3: Проверка из контейнера - попытка 1
print_info "Step 3: Testing from container (attempt 1)..."
if docker compose exec -T app php artisan db:show 2>&1 | grep -q "Connection:"; then
    print_success "Container can connect!"
    exit 0
fi

print_warning "Connection failed, trying fixes..."
echo ""

# Шаг 4: Анализ проблемы
print_info "Step 4: Analyzing connection problem..."

# Проверяем сеть
NETWORK_MODE=$(docker inspect $(docker compose ps -q app 2>/dev/null) --format='{{.HostConfig.NetworkMode}}' 2>/dev/null)
print_info "Network mode: $NETWORK_MODE"

if [ "$DB_HOST" = "localhost" ] || [ "$DB_HOST" = "127.0.0.1" ]; then
    if [ "$NETWORK_MODE" != "host" ]; then
        print_error "Problem: DB_HOST=localhost but network mode is not 'host'"
        echo ""
        print_info "Solution 1: Switch to host network mode"
        read -p "Switch to host network mode? [Y/n]: " switch
        switch=${switch:-Y}
        
        if [[ "$switch" =~ ^[Yy]$ ]]; then
            if [ -x ./scripts/switch-network-mode.sh ]; then
                print_info "Running network mode switch..."
                ./scripts/switch-network-mode.sh << EOF
2
EOF
                exit $?
            else
                print_warning "switch-network-mode.sh not found"
                print_info "Manual steps:"
                echo "  1. Use docker/docker-compose.host-network.yml:"
                echo "     cp docker/docker-compose.host-network.yml docker-compose.yml"
                echo "  2. Restart containers:"
                echo "     docker compose down && docker compose up -d"
                exit 1
            fi
        else
            print_info "Solution 2: Change DB_HOST to gateway IP"
            GATEWAY=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
            GATEWAY=${GATEWAY:-172.17.0.1}
            
            echo "  sed -i 's/DB_HOST=.*/DB_HOST=$GATEWAY/' .env"
            echo ""
            read -p "Apply this fix? [Y/n]: " apply
            apply=${apply:-Y}
            
            if [[ "$apply" =~ ^[Yy]$ ]]; then
                sed -i "s/DB_HOST=.*/DB_HOST=$GATEWAY/" .env
                print_success "Updated DB_HOST to $GATEWAY"
                
                # Нужно также настроить MariaDB
                print_info "Configuring MariaDB for Docker network..."
                
                sudo mysql -u root << EOF
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'172.%.%.%' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
EOF
                
                # Проверяем bind-address
                if grep -q "^bind-address.*127.0.0.1" /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null; then
                    print_warning "MariaDB bind-address is 127.0.0.1"
                    read -p "Change to 0.0.0.0? [Y/n]: " change_bind
                    change_bind=${change_bind:-Y}
                    
                    if [[ "$change_bind" =~ ^[Yy]$ ]]; then
                        sudo sed -i 's/^bind-address.*127.0.0.1/#bind-address = 127.0.0.1\nbind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
                        sudo systemctl restart mariadb
                        print_success "MariaDB restarted"
                        sleep 3
                    fi
                fi
                
                # Перезапускаем контейнеры
                print_info "Restarting containers..."
                docker compose down
                docker compose up -d
                sleep 5
            fi
        fi
    else
        print_error "Network mode is 'host' but connection still fails"
        print_info "Checking MariaDB..."
        
        if ! ss -tlnp 2>/dev/null | grep -q "127.0.0.1:3306"; then
            print_error "MariaDB is not listening on 127.0.0.1:3306"
            echo ""
            echo "Check MariaDB status:"
            echo "  sudo systemctl status mariadb"
            echo "  ss -tlnp | grep 3306"
            exit 1
        fi
    fi
else
    # DB_HOST не localhost
    print_info "DB_HOST is not localhost: $DB_HOST"
    
    # Проверяем что MariaDB слушает на этом IP
    if ! ss -tlnp 2>/dev/null | grep -q "0.0.0.0:3306"; then
        print_error "MariaDB is not listening on 0.0.0.0:3306"
        echo ""
        print_info "Fix MariaDB configuration:"
        echo "  sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf"
        echo "  Change: bind-address = 127.0.0.1"
        echo "  To:     bind-address = 0.0.0.0"
        echo "  Then:   sudo systemctl restart mariadb"
        exit 1
    fi
    
    # Проверяем права пользователя
    print_info "Checking user privileges..."
    GRANT_COUNT=$(sudo mysql -u root -e "SELECT COUNT(*) FROM mysql.user WHERE User='$DB_USER' AND Host LIKE '172.%'" -N 2>/dev/null)
    
    if [ "$GRANT_COUNT" = "0" ] || [ -z "$GRANT_COUNT" ]; then
        print_warning "User does not have grants for Docker network"
        print_info "Adding grants..."
        
        sudo mysql -u root << EOF
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'172.%.%.%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
EOF
        
        print_success "Grants added"
        
        # Перезапускаем контейнеры
        docker compose restart app
        sleep 5
    fi
fi

# Финальная проверка
echo ""
print_info "Final test: Testing connection from container..."
sleep 2

if docker compose exec -T app php artisan db:show 2>&1 | grep -q "Connection:"; then
    print_success "SUCCESS! Container can connect to database!"
    echo ""
    print_info "Database info:"
    docker compose exec -T app php artisan db:show | head -10
    echo ""
    print_success "You can now run migrations:"
    echo "  docker compose exec app php artisan migrate --seed"
else
    print_error "Connection still fails"
    echo ""
    print_warning "Detailed diagnostic:"
    
    # Показываем детальную ошибку
    echo ""
    echo "=== Error from container ==="
    docker compose exec -T app php artisan db:show 2>&1 | head -20
    echo "==========================="
    echo ""
    
    # Проверяем что контейнер видит хост
    print_info "Testing network from container:"
    echo ""
    echo "Can container reach host?"
    docker compose exec -T app ping -c 2 "$DB_HOST" 2>&1 || echo "Cannot ping $DB_HOST"
    echo ""
    
    echo "Can container reach port 3306?"
    docker compose exec -T app nc -zv "$DB_HOST" "$DB_PORT" 2>&1 || echo "Cannot reach $DB_HOST:$DB_PORT"
    echo ""
    
    print_error "Manual steps required:"
    echo ""
    echo "1. Check current configuration:"
    echo "   cat .env | grep DB_"
    echo "   docker compose ps"
    echo "   docker inspect \$(docker compose ps -q app) | grep NetworkMode"
    echo ""
    echo "2. Try host network mode:"
    echo "   ./scripts/switch-network-mode.sh"
    echo ""
    echo "3. Or fix current configuration:"
    echo "   ./scripts/diagnose-mariadb.sh"
    echo ""
    echo "4. Full diagnostic:"
    echo "   ./scripts/full-diagnostic.sh"
fi

echo ""
