#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║          Switch Docker Network Mode - QEMU Web Control                  ║"
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

# Проверяем текущий режим
if grep -q "network_mode.*host" docker-compose.yml 2>/dev/null; then
    CURRENT_MODE="host"
else
    CURRENT_MODE="bridge"
fi

print_info "Current network mode: $CURRENT_MODE"
echo ""

echo "Available network modes:"
echo ""
echo "1) Bridge Network (default)"
echo "   - Isolated containers"
echo "   - Custom ports (8080, 8443)"
echo "   - DB_HOST = gateway IP (172.17.0.1)"
echo "   - MariaDB must listen on 0.0.0.0"
echo ""
echo "2) Host Network (production)"
echo "   - No network isolation"
echo "   - Standard ports (80, 443)"
echo "   - DB_HOST = localhost (secure!)"
echo "   - MariaDB can stay on 127.0.0.1"
echo ""
echo "3) RISC-V Mode (no database container)"
echo "   - Bridge network without db service"
echo "   - Custom ports (8080, 8443)"
echo "   - DB_HOST = gateway IP or localhost with host mode"
echo ""

read -p "Select mode [1-3]: " mode

case $mode in
    1)
        print_info "Switching to Bridge Network mode..."
        
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up current docker-compose.yml"
        fi
        
        # Проверяем наличие стандартного compose
        if [ -f docker-compose.yml.original ]; then
            cp docker-compose.yml.original docker-compose.yml
        else
            print_warning "docker-compose.yml.original not found"
            print_info "Using docker-compose.yml with db service"
        fi
        
        # Обновляем nginx конфигурацию
        if [ -f docker/nginx/conf.d/default.conf.bridge ]; then
            cp docker/nginx/conf.d/default.conf.bridge docker/nginx/conf.d/default.conf
            print_success "Updated nginx configuration for bridge network"
        fi
        
        # Обновляем .env
        print_info "Updating .env..."
        
        # Находим gateway IP
        GATEWAY_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
        GATEWAY_IP=${GATEWAY_IP:-172.17.0.1}
        
        sed -i "s/DB_HOST=.*/DB_HOST=$GATEWAY_IP/" .env
        sed -i "s/APP_PORT=.*/APP_PORT=8080/" .env
        sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=8443/" .env
        
        print_success "Configuration updated:"
        echo "  DB_HOST=$GATEWAY_IP"
        echo "  APP_PORT=8080"
        echo "  APP_SSL_PORT=8443"
        
        print_warning "MariaDB configuration required:"
        echo "  sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf"
        echo "  Set: bind-address = 0.0.0.0"
        echo "  Then: sudo systemctl restart mariadb"
        ;;
        
    2)
        print_info "Switching to Host Network mode..."
        
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up current docker-compose.yml"
        fi
        
        if [ ! -f docker/docker-compose.host-network.yml ]; then
            print_error "docker/docker-compose.host-network.yml not found!"
            exit 1
        fi
        
        cp docker/docker-compose.host-network.yml docker-compose.yml
        print_success "Switched to host network docker-compose.yml"
        
        # Обновляем nginx конфигурацию
        if [ -f docker/nginx/conf.d/default.host-network.conf ]; then
            cp docker/nginx/conf.d/default.host-network.conf docker/nginx/conf.d/default.conf
            print_success "Updated nginx configuration for host network"
        else
            print_warning "default.host-network.conf not found, update manually:"
            echo "  In default.conf change: fastcgi_pass app:9000"
            echo "  To: fastcgi_pass 127.0.0.1:9000"
        fi
        
        # Обновляем .env
        print_info "Updating .env..."
        sed -i "s/DB_HOST=.*/DB_HOST=localhost/" .env
        sed -i "s/APP_PORT=.*/APP_PORT=80/" .env
        sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=443/" .env
        
        print_success "Configuration updated:"
        echo "  DB_HOST=localhost"
        echo "  APP_PORT=80"
        echo "  APP_SSL_PORT=443"
        
        print_success "MariaDB can stay on localhost (secure!):"
        echo "  bind-address = 127.0.0.1"
        ;;
        
    3)
        print_info "Switching to RISC-V mode (no database container)..."
        
        if [ ! -f docker-compose.yml.backup ]; then
            cp docker-compose.yml docker-compose.yml.backup
            print_success "Backed up current docker-compose.yml"
        fi
        
        if [ ! -f docker/docker-compose.riscv.yml ]; then
            print_error "docker/docker-compose.riscv.yml not found!"
            exit 1
        fi
        
        cp docker/docker-compose.riscv.yml docker-compose.yml
        print_success "Switched to RISC-V docker-compose.yml (no db container)"
        
        echo ""
        print_info "Choose database connection method:"
        echo "  1) Bridge network with gateway IP (default)"
        echo "  2) Host network with localhost (more secure)"
        echo ""
        read -p "Select [1-2]: " db_method
        
        if [ "$db_method" = "2" ]; then
            # Добавляем host network mode в docker/docker-compose.riscv.yml
            print_info "Updating docker-compose.yml to use host network..."
            
            sed -i '/^services:/,/^[^ ]/ {
                /container_name:/a\    network_mode: "host"
            }' docker-compose.yml
            
            sed -i "s/DB_HOST=.*/DB_HOST=localhost/" .env
            sed -i "s/APP_PORT=.*/APP_PORT=80/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=443/" .env
            
            print_success "Using host network with localhost database"
        else
            GATEWAY_IP=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
            GATEWAY_IP=${GATEWAY_IP:-172.17.0.1}
            
            sed -i "s/DB_HOST=.*/DB_HOST=$GATEWAY_IP/" .env
            sed -i "s/APP_PORT=.*/APP_PORT=8080/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=8443/" .env
            
            print_success "Using bridge network with gateway IP: $GATEWAY_IP"
        fi
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_info "Restarting containers..."
docker compose down
sleep 2
docker compose up -d

if [ $? -eq 0 ]; then
    print_success "Containers restarted successfully!"
    
    sleep 3
    
    print_info "Testing database connection..."
    if docker compose exec -T app php artisan db:show 2>&1 | grep -q "Connection:"; then
        print_success "Database connection OK!"
    else
        print_warning "Database connection failed"
        echo ""
        echo "Troubleshooting:"
        echo "  - Check MariaDB is running: sudo systemctl status mariadb"
        echo "  - Run diagnostic: ./scripts/diagnose-mariadb.sh"
        echo "  - Check configuration: cat .env | grep DB_"
    fi
    
    echo ""
    APP_PORT=$(grep APP_PORT .env | cut -d '=' -f2)
    APP_SSL_PORT=$(grep APP_SSL_PORT .env | cut -d '=' -f2)
    
    print_success "Application is available at:"
    echo "  HTTP:  http://localhost:${APP_PORT}"
    echo "  HTTPS: https://localhost:${APP_SSL_PORT}"
else
    print_error "Failed to start containers"
    echo ""
    echo "Check logs:"
    echo "  docker compose logs"
fi

echo ""
print_info "Network mode switched to: $mode"
echo ""
print_info "Configuration summary:"
cat .env | grep -E "^(DB_HOST|APP_PORT|APP_SSL_PORT)="
echo ""
