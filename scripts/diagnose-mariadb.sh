#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/safe-rm.sh
source "${SCRIPT_DIR}/scripts/safe-rm.sh" 2>/dev/null || true

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║        Diagnose and Fix MariaDB Connection from Docker                  ║"
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
print_section() { echo -e "\n${CYAN}═══ $1 ═══${NC}\n"; }

# Читаем конфигурацию
if [ ! -f .env ]; then
    print_error ".env file not found!"
    exit 1
fi

DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)

print_section "1. CURRENT CONFIGURATION"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo ""

# Проверка 1: MariaDB запущена?
print_section "2. MARIADB SERVICE STATUS"

if systemctl is-active --quiet mariadb; then
    print_success "MariaDB service is running"
elif systemctl is-active --quiet mysql; then
    print_success "MySQL service is running"
else
    print_error "MariaDB/MySQL service is not running!"
    echo ""
    print_info "Starting MariaDB..."
    sudo systemctl start mariadb
    sleep 2
    
    if systemctl is-active --quiet mariadb; then
        print_success "MariaDB started"
    else
        print_error "Failed to start MariaDB"
        echo ""
        echo "Check logs:"
        echo "  sudo journalctl -u mariadb -n 50"
        exit 1
    fi
fi

# Проверка 2: На каких интерфейсах слушает MariaDB?
print_section "3. MARIADB LISTENING ADDRESSES"

print_info "Checking which addresses MariaDB is listening on..."
LISTENING=$(ss -tlnp 2>/dev/null | grep :3306 || netstat -tlnp 2>/dev/null | grep :3306)

if [ -n "$LISTENING" ]; then
    echo "$LISTENING"
    echo ""
    
    if echo "$LISTENING" | grep -q "127.0.0.1:3306"; then
        print_error "MariaDB is listening ONLY on 127.0.0.1 (localhost)"
        print_warning "This prevents Docker containers from connecting!"
        BIND_ISSUE=true
    elif echo "$LISTENING" | grep -q "0.0.0.0:3306"; then
        print_success "MariaDB is listening on all interfaces (0.0.0.0)"
        BIND_ISSUE=false
    elif echo "$LISTENING" | grep -q ":::3306"; then
        print_success "MariaDB is listening on all IPv6 interfaces"
        BIND_ISSUE=false
    else
        print_warning "MariaDB is listening on specific interface"
        BIND_ISSUE=maybe
    fi
else
    print_error "MariaDB is not listening on port 3306!"
    exit 1
fi

# Проверка 3: Конфигурация bind-address
print_section "4. MARIADB BIND-ADDRESS CONFIGURATION"

MARIADB_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"
MYSQL_CNF="/etc/mysql/mysql.conf.d/mysqld.cnf"

if [ -f "$MARIADB_CNF" ]; then
    CONFIG_FILE="$MARIADB_CNF"
elif [ -f "$MYSQL_CNF" ]; then
    CONFIG_FILE="$MYSQL_CNF"
else
    print_warning "Cannot find MariaDB configuration file"
    CONFIG_FILE=""
fi

if [ -n "$CONFIG_FILE" ]; then
    print_info "Configuration file: $CONFIG_FILE"
    
    if grep -q "^bind-address.*127.0.0.1" "$CONFIG_FILE"; then
        print_error "bind-address is set to 127.0.0.1"
        echo ""
        BIND_CONFIG_ISSUE=true
    elif grep -q "^bind-address" "$CONFIG_FILE"; then
        BIND_ADDR=$(grep "^bind-address" "$CONFIG_FILE" | awk '{print $NF}')
        print_success "bind-address = $BIND_ADDR"
        BIND_CONFIG_ISSUE=false
    else
        print_info "bind-address is not set (default: 0.0.0.0)"
        BIND_CONFIG_ISSUE=false
    fi
fi

# Проверка 4: Firewall
print_section "5. FIREWALL STATUS"

if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        print_warning "UFW firewall is active"
        
        if sudo ufw status | grep -q "3306"; then
            print_success "Port 3306 is allowed in UFW"
        else
            print_error "Port 3306 is NOT allowed in UFW"
            FIREWALL_ISSUE=true
        fi
    else
        print_info "UFW firewall is inactive"
        FIREWALL_ISSUE=false
    fi
elif command -v firewall-cmd &> /dev/null; then
    if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
        print_warning "Firewalld is active"
        
        if sudo firewall-cmd --list-ports | grep -q "3306"; then
            print_success "Port 3306 is allowed in firewalld"
        else
            print_error "Port 3306 is NOT allowed in firewalld"
            FIREWALL_ISSUE=true
        fi
    else
        print_info "Firewalld is inactive"
        FIREWALL_ISSUE=false
    fi
else
    print_info "No firewall detected (or iptables)"
    FIREWALL_ISSUE=false
fi

# Проверка 5: Подключение с хоста
print_section "6. CONNECTION TEST FROM HOST"

print_info "Testing connection to $DB_HOST:$DB_PORT..."

if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>/tmp/mysql_test.log; then
    print_success "Can connect from host"
    HOST_CAN_CONNECT=true
else
    print_error "Cannot connect from host"
    echo ""
    echo "Error:"
    cat /tmp/mysql_test.log
    echo ""
    HOST_CAN_CONNECT=false
fi

# Проверка 6: Права пользователя
print_section "7. USER PRIVILEGES"

print_info "Checking user privileges..."

sudo mysql -u root << EOF 2>/dev/null | grep -v "User\|----"
SELECT User, Host FROM mysql.user WHERE User='$DB_USER';
EOF

echo ""
print_info "User '$DB_USER' should have grants for:"
echo "  - localhost"
echo "  - 172.%.%.% (Docker network)"
echo "  - $DB_HOST (if using specific IP)"

# РЕШЕНИЯ
print_section "8. PROBLEMS FOUND & SOLUTIONS"

PROBLEMS_FOUND=0

# Решение 1: bind-address
if [ "$BIND_CONFIG_ISSUE" = true ]; then
    print_error "PROBLEM: MariaDB bind-address restricts connections"
    echo ""
    echo "Solution:"
    echo "  sudo nano $CONFIG_FILE"
    echo "  Change: bind-address = 127.0.0.1"
    echo "  To:     bind-address = 0.0.0.0"
    echo "  Or comment it out: #bind-address = 127.0.0.1"
    echo "  Then: sudo systemctl restart mariadb"
    echo ""
    
    read -p "Fix bind-address now? [Y/n]: " fix_bind
    fix_bind=${fix_bind:-Y}
    
    if [[ "$fix_bind" =~ ^[Yy]$ ]]; then
        print_info "Fixing bind-address..."
        
        sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        sudo sed -i 's/^bind-address.*127.0.0.1/#bind-address = 127.0.0.1\nbind-address = 0.0.0.0/' "$CONFIG_FILE"
        
        print_info "Restarting MariaDB..."
        sudo systemctl restart mariadb
        sleep 3
        
        if systemctl is-active --quiet mariadb; then
            print_success "MariaDB restarted successfully"
        else
            print_error "MariaDB failed to restart, restoring backup"
            sudo mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
            sudo systemctl restart mariadb
        fi
    fi
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

# Решение 2: Firewall
if [ "$FIREWALL_ISSUE" = true ]; then
    print_error "PROBLEM: Firewall blocks port 3306"
    echo ""
    
    read -p "Open port 3306 in firewall? [Y/n]: " fix_firewall
    fix_firewall=${fix_firewall:-Y}
    
    if [[ "$fix_firewall" =~ ^[Yy]$ ]]; then
        if command -v ufw &> /dev/null; then
            print_info "Opening port 3306 in UFW..."
            sudo ufw allow 3306/tcp
            print_success "Port opened"
        elif command -v firewall-cmd &> /dev/null; then
            print_info "Opening port 3306 in firewalld..."
            sudo firewall-cmd --permanent --add-port=3306/tcp
            sudo firewall-cmd --reload
            print_success "Port opened"
        fi
    fi
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

# Решение 3: Права пользователя
print_error "PROBLEM: User may not have privileges for Docker network"
echo ""

read -p "Update user privileges for Docker network? [Y/n]: " fix_grants
fix_grants=${fix_grants:-Y}

if [[ "$fix_grants" =~ ^[Yy]$ ]]; then
    print_info "Updating user privileges..."
    
    sudo mysql -u root << EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'172.%.%.%' IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'172.%.%.%';

FLUSH PRIVILEGES;
EOF
    
    print_success "User privileges updated"
    echo ""
    
    print_info "User grants:"
    sudo mysql -u root -e "SHOW GRANTS FOR '${DB_USER}'@'%';" 2>/dev/null || true
fi

# Решение 4: Использовать Docker gateway вместо IP хоста
print_section "9. RECOMMENDED DB_HOST"

print_info "Finding best DB_HOST value..."

# Получаем Docker gateway
DOCKER_GATEWAY=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)

echo ""
echo "Recommended DB_HOST values:"
echo "  1) $DOCKER_GATEWAY (Docker gateway - most reliable)"
echo "  2) 172.17.0.1 (standard Docker gateway)"
echo "  3) $(hostname -I | awk '{print $1}') (host IP)"
echo ""
echo "Current: $DB_HOST"
echo ""

if [ "$DB_HOST" != "$DOCKER_GATEWAY" ] && [ "$DB_HOST" != "172.17.0.1" ]; then
    read -p "Change DB_HOST to $DOCKER_GATEWAY? [Y/n]: " change_host
    change_host=${change_host:-Y}
    
    if [[ "$change_host" =~ ^[Yy]$ ]]; then
        sed -i "s/DB_HOST=.*/DB_HOST=$DOCKER_GATEWAY/" .env
        print_success "Updated .env: DB_HOST=$DOCKER_GATEWAY"
        
        # Обновляем переменную для финальной проверки
        DB_HOST=$DOCKER_GATEWAY
    fi
fi

# Финальная проверка
print_section "10. FINAL CONNECTION TEST"

print_info "Testing connection with current settings..."
print_info "Waiting 3 seconds for changes to take effect..."
sleep 3

if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/tmp/final_test.log; then
    print_success "Connection successful!"
    echo ""
    
    # Тест из контейнера
    if docker compose ps -q app &> /dev/null 2>&1; then
        print_info "Testing from Docker container..."
        docker compose restart app &>/dev/null
        sleep 3
        
        if docker compose exec -T app php artisan db:show 2>&1 | grep -q "Connection:"; then
            print_success "Docker container can connect to database!"
            echo ""
            print_success "ALL CHECKS PASSED!"
            echo ""
            echo "You can now run migrations:"
            echo "  docker compose exec app php artisan migrate --seed"
        else
            print_warning "Docker container still cannot connect"
            echo ""
            echo "Try:"
            echo "  docker compose down"
            echo "  docker compose up -d"
            echo "  docker compose exec app php artisan db:show"
        fi
    fi
else
    print_error "Connection still fails"
    echo ""
    echo "Error:"
    cat /tmp/final_test.log
    echo ""
    echo "Manual steps to try:"
    echo ""
    echo "1. Check MariaDB is listening on correct interface:"
    echo "   ss -tlnp | grep 3306"
    echo ""
    echo "2. Test direct connection:"
    echo "   mysql -h $DB_HOST -u $DB_USER -p"
    echo ""
    echo "3. Check user grants:"
    echo "   sudo mysql -u root -e \"SHOW GRANTS FOR '$DB_USER'@'%';\""
    echo ""
    echo "4. Try using localhost socket instead:"
    echo "   In .env: DB_HOST=/var/run/mysqld/mysqld.sock"
fi

# Очистка
safe_rm_f /tmp/mysql_test.log /tmp/final_test.log 2>/dev/null || rm -f /tmp/mysql_test.log /tmp/final_test.log

echo ""
print_info "Diagnostic complete!"
echo ""
