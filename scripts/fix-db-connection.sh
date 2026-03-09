#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║          Fix Database Connection from Docker Container                  ║"
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

# Проверяем .env
if [ ! -f .env ]; then
    print_error ".env file not found!"
    exit 1
fi

# Читаем текущую конфигурацию
DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)

print_info "Current database configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Проверяем подключение с хоста
print_info "Testing connection from host..."

if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>/dev/null; then
    print_success "Host can connect to database"
else
    print_error "Host cannot connect to database"
    echo ""
    print_warning "Please setup database first:"
    echo "  ./scripts/setup-database.sh"
    exit 1
fi

# Проверяем существование БД
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    print_success "Database '$DB_NAME' exists"
else
    print_error "Database '$DB_NAME' does not exist"
    echo ""
    print_info "Run: ./scripts/setup-database.sh"
    exit 1
fi

# Проблема: Docker контейнер не может подключиться к localhost хоста
echo ""
print_warning "Problem: Docker container cannot connect to host's localhost"
echo ""
echo "When Docker container tries to connect to 'localhost', it connects to"
echo "itself, not to the host machine's localhost."
echo ""

# Определяем IP хоста
print_info "Finding host IP address..."

# Пробуем разные методы
HOST_IP=""

# Метод 1: Gateway IP из Docker
if command -v docker &> /dev/null; then
    GATEWAY_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
    if [ -n "$GATEWAY_IP" ]; then
        print_success "Found Docker gateway: $GATEWAY_IP"
        HOST_IP=$GATEWAY_IP
    fi
fi

# Метод 2: IP адрес хоста
if [ -z "$HOST_IP" ]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [ -n "$LOCAL_IP" ]; then
        print_success "Found host IP: $LOCAL_IP"
        HOST_IP=$LOCAL_IP
    fi
fi

# Метод 3: Используем host.docker.internal (работает на некоторых системах)
if [ -z "$HOST_IP" ]; then
    print_warning "Cannot determine host IP automatically"
    HOST_IP="host.docker.internal"
fi

echo ""
print_info "Recommended DB_HOST values:"
echo ""
echo "1) Docker gateway (recommended): $GATEWAY_IP"
echo "2) Host IP address: $(hostname -I | awk '{print $1}')"
echo "3) host.docker.internal (may not work on Linux)"
echo ""

read -p "Enter new DB_HOST [default: $GATEWAY_IP]: " new_host
new_host=${new_host:-$GATEWAY_IP}

# Тестируем подключение с нового хоста
print_info "Testing connection to $new_host..."

if mysql -h "$new_host" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    print_success "Connection successful!"
    
    # Обновляем .env
    sed -i "s/DB_HOST=.*/DB_HOST=$new_host/" .env
    print_success "Updated .env: DB_HOST=$new_host"
    
    # Нужно настроить MariaDB для приема внешних подключений
    echo ""
    print_info "Configuring MariaDB to accept connections from Docker..."
    
    # Проверяем bind-address
    MARIADB_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
    
    if [ -f "$MARIADB_CNF" ]; then
        if grep -q "^bind-address.*127.0.0.1" "$MARIADB_CNF"; then
            print_warning "MariaDB is configured to listen only on 127.0.0.1"
            echo ""
            read -p "Update MariaDB configuration to listen on all interfaces? [Y/n]: " update_config
            update_config=${update_config:-Y}
            
            if [[ "$update_config" =~ ^[Yy]$ ]]; then
                print_info "Updating MariaDB configuration..."
                
                # Бэкап
                sudo cp "$MARIADB_CNF" "${MARIADB_CNF}.backup"
                
                # Комментируем bind-address или меняем на 0.0.0.0
                sudo sed -i 's/^bind-address.*127.0.0.1/#bind-address = 127.0.0.1\nbind-address = 0.0.0.0/' "$MARIADB_CNF"
                
                print_success "Configuration updated"
                print_info "Restarting MariaDB..."
                
                sudo systemctl restart mariadb
                sleep 2
                
                if sudo systemctl is-active --quiet mariadb; then
                    print_success "MariaDB restarted"
                else
                    print_error "MariaDB failed to restart"
                    print_warning "Restoring backup configuration..."
                    sudo mv "${MARIADB_CNF}.backup" "$MARIADB_CNF"
                    sudo systemctl restart mariadb
                fi
            fi
        else
            print_success "MariaDB already configured to accept external connections"
        fi
    fi
    
    # Обновляем права пользователя для Docker сети
    print_info "Updating user privileges for Docker network..."
    
    DOCKER_NETWORK="172.%.%.%"
    
    sudo mysql -u root << EOF 2>/dev/null
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DOCKER_NETWORK}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${new_host}' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
EOF
    
    print_success "User privileges updated"
    
    # Тестируем из контейнера
    echo ""
    print_info "Testing connection from Docker container..."
    
    if docker compose ps -q app &> /dev/null; then
        if docker compose exec -T app php artisan db:show 2>&1 | grep -q "Connection:"; then
            print_success "Container can connect to database!"
            echo ""
            print_success "Configuration complete!"
            echo ""
            echo "You can now run migrations:"
            echo "  docker compose exec app php artisan migrate --seed"
        else
            print_warning "Container still cannot connect"
            echo ""
            echo "Try restarting containers:"
            echo "  docker compose restart"
            echo "  docker compose exec app php artisan db:show"
        fi
    else
        print_warning "Containers are not running"
        echo ""
        echo "Start containers and test:"
        echo "  docker compose up -d"
        echo "  docker compose exec app php artisan db:show"
    fi
    
else
    print_error "Cannot connect to database at $new_host"
    echo ""
    echo "Possible solutions:"
    echo ""
    echo "1. Configure MariaDB to accept connections from Docker:"
    echo "   sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf"
    echo "   Change: bind-address = 127.0.0.1"
    echo "   To:     bind-address = 0.0.0.0"
    echo "   Then:   sudo systemctl restart mariadb"
    echo ""
    echo "2. Grant privileges to Docker network:"
    echo "   sudo mysql -u root -p"
    echo "   GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'172.%.%.%' IDENTIFIED BY '${DB_PASS}';"
    echo "   FLUSH PRIVILEGES;"
    echo ""
    echo "3. Use Docker database instead:"
    echo "   ./scripts/fix-database-riscv.sh"
fi

echo ""
print_info "Current .env configuration:"
grep "^DB_" .env
echo ""
