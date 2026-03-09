#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║              Quick Fix After Failed Installation on RISC-V               ║"
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
    exit 0
fi

print_info "Detected RISC-V architecture"
echo ""

# Проверяем .env
if [ ! -f .env ]; then
    print_error ".env file not found!"
    echo "Please run install.sh first to create .env"
    exit 1
fi

# Читаем DB_HOST из .env
DB_HOST=$(grep DB_HOST .env | cut -d '=' -f2)

print_info "Current database configuration:"
echo "  DB_HOST: $DB_HOST"
echo ""

if [ "$DB_HOST" = "db" ]; then
    print_warning "You are configured to use Docker database"
    print_warning "But MariaDB Docker image is not available for RISC-V!"
    echo ""
    print_info "Switching to external database configuration..."
    
    # Запускаем fix-database-riscv.sh
    if [ -x ./scripts/fix-database-riscv.sh ]; then
        ./scripts/fix-database-riscv.sh
    else
        print_error "fix-database-riscv.sh not found or not executable"
        echo ""
        echo "Manual steps:"
        echo "  1. Install MariaDB: sudo apt-get install -y mariadb-server"
        echo "  2. Start MariaDB: sudo systemctl start mariadb"
        echo "  3. Update .env: DB_HOST=localhost"
        echo "  4. Switch compose: cp docker/docker-compose.riscv.yml docker-compose.yml"
        echo "  5. Create database: ./scripts/setup-database.sh"
        exit 1
    fi
else
    print_success "You are using external database: $DB_HOST"
    echo ""
    
    print_info "Checking if docker-compose.yml has 'db' service..."
    if grep -q "^  db:" docker-compose.yml; then
        print_warning "Found 'db' service in docker-compose.yml"
        print_info "This will cause 'no matching manifest' error on RISC-V"
        echo ""
        
        read -p "Switch to docker/docker-compose.riscv.yml (without DB container)? [Y/n]: " switch
        switch=${switch:-Y}
        
        if [[ "$switch" =~ ^[Yy]$ ]]; then
            if [ -f docker/docker-compose.riscv.yml ]; then
                # Бэкап
                if [ ! -f docker-compose.yml.backup ]; then
                    cp docker-compose.yml docker-compose.yml.backup
                    print_success "Backed up docker-compose.yml"
                fi
                
                # Переключаем
                cp docker/docker-compose.riscv.yml docker-compose.yml
                print_success "Switched to docker/docker-compose.riscv.yml"
                
                # Останавливаем старые контейнеры
                print_info "Stopping old containers..."
                docker compose down 2>/dev/null
                
                # Запускаем новые
                print_info "Starting containers (without DB)..."
                docker compose up -d
                
                if [ $? -eq 0 ]; then
                    print_success "Containers started successfully!"
                    
                    # Проверяем БД
                    echo ""
                    print_info "Checking database connection..."
                    
                    DB_NAME=$(grep DB_DATABASE .env | cut -d '=' -f2)
                    DB_USER=$(grep DB_USERNAME .env | cut -d '=' -f2)
                    DB_PASS=$(grep DB_PASSWORD .env | cut -d '=' -f2)
                    DB_PORT=$(grep DB_PORT .env | cut -d '=' -f2)
                    
                    if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "USE $DB_NAME" 2>/dev/null; then
                        print_success "Database connection OK"
                        
                        # Проверяем миграции
                        print_info "Checking migrations..."
                        MIGRATION_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='migrations'" -N 2>/dev/null)
                        
                        if [ "$MIGRATION_COUNT" = "0" ] || [ -z "$MIGRATION_COUNT" ]; then
                            print_warning "Migrations not run yet"
                            echo ""
                            read -p "Run migrations now? [Y/n]: " run_migrations
                            run_migrations=${run_migrations:-Y}
                            
                            if [[ "$run_migrations" =~ ^[Yy]$ ]]; then
                                print_info "Running migrations..."
                                docker compose exec -T app php artisan migrate --seed --force
                                
                                if [ $? -eq 0 ]; then
                                    print_success "Migrations completed!"
                                else
                                    print_error "Migration failed"
                                    echo ""
                                    echo "Try manually:"
                                    echo "  docker compose exec app php artisan migrate --seed"
                                fi
                            fi
                        else
                            print_success "Migrations already run"
                        fi
                    else
                        print_error "Cannot connect to database!"
                        echo ""
                        print_info "Run setup-database.sh to create database:"
                        echo "  ./scripts/setup-database.sh"
                    fi
                    
                    echo ""
                    print_success "Setup complete!"
                    echo ""
                    echo "Access the application:"
                    APP_PORT=$(grep APP_PORT .env | cut -d '=' -f2)
                    APP_SSL_PORT=$(grep APP_SSL_PORT .env | cut -d '=' -f2)
                    echo "  HTTP:  http://$(hostname -I | awk '{print $1}'):${APP_PORT}"
                    echo "  HTTPS: https://$(hostname -I | awk '{print $1}'):${APP_SSL_PORT}"
                    echo ""
                    echo "Default credentials:"
                    echo "  Login:    admin"
                    echo "  Password: admin"
                else
                    print_error "Failed to start containers"
                    echo ""
                    echo "Check logs:"
                    echo "  docker compose logs"
                fi
            else
                print_error "docker/docker-compose.riscv.yml not found!"
                exit 1
            fi
        else
            print_info "Skipped switching"
        fi
    else
        print_success "docker-compose.yml already configured for external DB"
        echo ""
        print_info "Starting containers..."
        docker compose up -d
        
        if [ $? -eq 0 ]; then
            print_success "Containers started!"
        else
            print_error "Failed to start containers"
            echo ""
            echo "Check logs:"
            echo "  docker compose logs"
        fi
    fi
fi

echo ""
print_info "Useful commands:"
echo "  docker compose ps              # Check container status"
echo "  docker compose logs -f         # View logs"
echo "  docker compose exec app bash   # Enter app container"
echo "  ./scripts/diagnose.sh                  # Full diagnostic"
echo ""
