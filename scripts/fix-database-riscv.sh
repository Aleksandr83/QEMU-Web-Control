#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           Switch to External Database for RISC-V - Quick Fix            ║"
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

# Проверяем архитектуру
ARCH=$(uname -m)
if [ "$ARCH" != "riscv64" ]; then
    print_warning "This script is for RISC-V architecture only"
    print_info "Current architecture: $ARCH"
    print_info "For standard architectures, MariaDB Docker container works fine"
    exit 0
fi

print_info "Detected RISC-V architecture"
print_warning "MariaDB Docker image is not available for RISC-V"
echo ""

# Проверяем .env
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Please run install.sh first"
    exit 1
fi

echo "Solutions for MariaDB on RISC-V:"
echo ""
echo "1) Install MariaDB on host system (recommended)"
echo "2) Use docker/docker-compose.riscv.yml (without DB container)"
echo "3) Use PostgreSQL in Docker (experimental)"
echo "4) Use SQLite (lightweight, single file)"
echo ""
read -p "Select option [1-4]: " option

case $option in
    1)
        print_info "Installing MariaDB on host system..."
        
        # Проверяем, не установлена ли уже
        if command -v mysql &> /dev/null; then
            MYSQL_VERSION=$(mysql --version)
            print_warning "MariaDB/MySQL already installed: $MYSQL_VERSION"
            read -p "Reinstall? [y/n]: " reinstall
            if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
                print_info "Skipping installation"
            fi
        else
            # Устанавливаем MariaDB
            print_info "Installing MariaDB server..."
            sudo apt-get update
            sudo apt-get install -y mariadb-server mariadb-client
            
            if [ $? -eq 0 ]; then
                print_success "MariaDB installed"
                
                # Запускаем
                sudo systemctl start mariadb
                sudo systemctl enable mariadb
                print_success "MariaDB started and enabled"
            else
                print_error "Failed to install MariaDB"
                exit 1
            fi
        fi
        
        # Настраиваем .env для локальной БД
        print_info "Configuring .env for host database..."
        sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
        sed -i 's/DB_PORT=.*/DB_PORT=3306/' .env
        print_success ".env updated to use localhost database"
        
        # Используем docker-compose без БД
        print_info "Switching to docker/docker-compose.riscv.yml..."
        if [ ! -f docker/docker-compose.riscv.yml ]; then
            print_error "docker/docker-compose.riscv.yml not found!"
            exit 1
        fi
        
        # Бэкап оригинального
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up original docker-compose.yml"
        fi
        
        cp docker/docker-compose.riscv.yml docker-compose.yml
        print_success "Switched to RISC-V compose configuration"
        
        # Настраиваем БД
        echo ""
        print_info "Setting up database..."
        
        if [ -x "$SCRIPT_DIR/setup-database.sh" ]; then
            "$SCRIPT_DIR/setup-database.sh"
        else
            print_warning "setup-database.sh not found, please create database manually"
            echo ""
            echo "Run these commands:"
            echo "  sudo mysql"
            echo "  CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            echo "  CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';"
            echo "  GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';"
            echo "  FLUSH PRIVILEGES;"
            echo "  EXIT;"
        fi
        
        echo ""
        print_success "Configuration complete!"
        echo ""
        echo "Now you can start the application:"
        echo "  docker compose down"
        echo "  docker compose up -d"
        ;;
        
    2)
        print_info "Using docker/docker-compose.riscv.yml..."
        
        if [ ! -f docker/docker-compose.riscv.yml ]; then
            print_error "docker/docker-compose.riscv.yml not found!"
            exit 1
        fi
        
        # Бэкап и замена
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up original docker-compose.yml"
        fi
        
        cp docker/docker-compose.riscv.yml docker-compose.yml
        print_success "Switched to RISC-V compose configuration (no DB container)"
        
        # Проверяем DB_HOST в .env
        DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)
        if [ "$DB_HOST" = "db" ]; then
            print_warning "DB_HOST is set to 'db' (Docker container)"
            echo ""
            read -p "Enter database host [localhost]: " new_host
            new_host=${new_host:-localhost}
            sed -i "s/DB_HOST=.*/DB_HOST=$new_host/" .env
            print_success "Updated DB_HOST to $new_host"
        fi
        
        print_success "Configuration updated"
        echo ""
        echo "Make sure you have MariaDB/MySQL running on $DB_HOST"
        echo "Then run: docker compose up -d"
        ;;
        
    3)
        print_warning "PostgreSQL support is experimental"
        print_info "This will require changes to Laravel configuration"
        echo ""
        read -p "Continue? [y/n]: " continue
        
        if [[ ! "$continue" =~ ^[Yy]$ ]]; then
            exit 0
        fi
        
        print_info "Installing PostgreSQL..."
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        
        if [ $? -eq 0 ]; then
            print_success "PostgreSQL installed"
            
            # Обновляем .env
            sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=pgsql/' .env
            sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
            sed -i 's/DB_PORT=.*/DB_PORT=5432/' .env
            
            print_success "Configuration updated for PostgreSQL"
            
            # Используем compose без БД
            cp docker/docker-compose.riscv.yml docker-compose.yml
            print_success "Switched to RISC-V compose configuration"
            
            echo ""
            print_warning "You need to create PostgreSQL database manually:"
            echo "  sudo -u postgres psql"
            echo "  CREATE DATABASE qemu_control;"
            echo "  CREATE USER qemu_user WITH PASSWORD 'qemu_password';"
            echo "  GRANT ALL PRIVILEGES ON DATABASE qemu_control TO qemu_user;"
            echo "  \\q"
        else
            print_error "Failed to install PostgreSQL"
            exit 1
        fi
        ;;
        
    4)
        print_info "Configuring SQLite..."
        print_warning "SQLite doesn't support some features, but works for basic usage"
        
        # Обновляем .env
        sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
        sed -i 's/DB_HOST=.*/# DB_HOST=/' .env
        sed -i 's/DB_PORT=.*/# DB_PORT=/' .env
        sed -i 's/DB_DATABASE=.*/# DB_DATABASE=/' .env
        sed -i 's/DB_USERNAME=.*/# DB_USERNAME=/' .env
        sed -i 's/DB_PASSWORD=.*/# DB_PASSWORD=/' .env
        
        # Создаем файл БД
        mkdir -p database
        touch database/database.sqlite
        chmod 664 database/database.sqlite
        
        print_success "SQLite database created at database/database.sqlite"
        
        # Используем compose без БД
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up original docker-compose.yml"
        fi
        
        cp docker/docker-compose.riscv.yml docker-compose.yml
        print_success "Switched to RISC-V compose configuration"
        
        echo ""
        print_success "SQLite configuration complete!"
        echo ""
        echo "Now run:"
        echo "  docker compose down"
        echo "  docker compose up -d"
        echo "  docker compose exec app php artisan migrate --seed"
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_info "Useful commands after setup:"
echo "  docker compose up -d               # Start containers"
echo "  docker compose exec app php artisan migrate --seed  # Run migrations"
echo "  ./scripts/diagnose.sh                      # System diagnostic"
echo ""
