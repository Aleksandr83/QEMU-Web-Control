#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/safe-rm.sh
source "${SCRIPT_DIR}/scripts/safe-rm.sh" 2>/dev/null || true

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                Database Setup Helper for QEMU Web Control                ║"
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

# Читаем параметры из .env
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Run: cp .env.example .env"
    exit 1
fi

DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)

echo "Database configuration from .env:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Проверка mysql клиента
if ! command -v mysql &> /dev/null; then
    print_error "MySQL client not installed!"
    echo ""
    read -p "Install mysql-client? [y/n]: " install_client
    if [[ "$install_client" =~ ^[Yy]$ ]]; then
        sudo apt-get update
        sudo apt-get install -y mysql-client mariadb-client 2>/dev/null || sudo apt-get install -y default-mysql-client
    else
        exit 1
    fi
fi

# 1. Проверка подключения к серверу
print_info "Testing connection to MySQL server..."
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" 2>/tmp/db_test_error.log; then
    print_success "Connection successful as user '$DB_USER'"
else
    print_error "Cannot connect to MySQL server as user '$DB_USER'"
    echo "Error details:"
    cat /tmp/db_test_error.log
    echo ""
    print_warning "Possible causes:"
    echo "  1. MySQL/MariaDB server is not running"
    echo "  2. Wrong credentials in .env"
    echo "  3. User '$DB_USER' does not exist"
    echo ""
    
    read -p "Try to connect as root to create user? [y/n]: " try_root
    if [[ ! "$try_root" =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    read -sp "Enter MySQL root password: " ROOT_PASS
    echo ""
    
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" -e "SELECT 1" 2>/tmp/db_root_error.log; then
        print_success "Connected as root"
        
        # Создаем пользователя
        print_info "Creating user '$DB_USER'..."
        mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" << EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'172.17.0.%' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
EOF
        print_success "User created"
    else
        print_error "Cannot connect as root"
        cat /tmp/db_root_error.log
        exit 1
    fi
fi

# 2. Проверка существования БД
print_info "Checking if database '$DB_NAME' exists..."
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
    print_success "Database '$DB_NAME' exists"
    
    # Показываем таблицы
    echo ""
    print_info "Tables in database:"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SHOW TABLES" "$DB_NAME" 2>/dev/null || echo "  (empty)"
    echo ""
    
    read -p "Database exists. Recreate it? [y/n]: " recreate
    if [[ ! "$recreate" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing database"
        exit 0
    fi
    
    read -sp "Enter root password to drop database: " ROOT_PASS
    echo ""
    
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" -e "DROP DATABASE IF EXISTS $DB_NAME" 2>/dev/null
    print_success "Database dropped"
fi

# 3. Создание БД
print_info "Creating database '$DB_NAME'..."

# Сначала пробуем от пользователя
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci" 2>/tmp/db_create_error.log; then
    # Проверяем что создалась
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
        print_success "Database created by user"
    else
        print_error "CREATE returned success but database not found!"
        cat /tmp/db_create_error.log
        exit 1
    fi
else
    # Пробуем от root
    print_warning "User cannot create database, trying root..."
    cat /tmp/db_create_error.log
    echo ""
    
    if [ -z "$ROOT_PASS" ]; then
        read -sp "Enter MySQL root password: " ROOT_PASS
        echo ""
    fi
    
    if mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci" 2>/tmp/db_root_create_error.log; then
        # Проверяем
        if mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" -e "USE $DB_NAME" 2>/dev/null; then
            print_success "Database created by root"
            
            # Даем права пользователю
            print_info "Granting privileges to '$DB_USER'..."
            mysql -h "$DB_HOST" -P "$DB_PORT" -u root -p"$ROOT_PASS" << EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'172.17.0.%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'172.17.0.%';
FLUSH PRIVILEGES;
EOF
            print_success "Privileges granted"
            
            # Финальная проверка
            if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
                print_success "User can access database - SUCCESS!"
            else
                print_error "User still cannot access database!"
                exit 1
            fi
        else
            print_error "CREATE returned success but database not found!"
            cat /tmp/db_root_create_error.log
            exit 1
        fi
    else
        print_error "Failed to create database even as root"
        cat /tmp/db_root_create_error.log
        exit 1
    fi
fi

# 4. Показываем список БД
echo ""
print_info "All databases on server:"
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES" 2>/dev/null

echo ""
print_success "Database setup complete!"
echo ""
echo "You can now run migrations:"
echo "  docker compose exec app php artisan migrate --seed"
echo ""

# Очистка
safe_rm_f /tmp/db_*.log 2>/dev/null || rm -f /tmp/db_*.log
