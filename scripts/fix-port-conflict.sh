#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                    Fix Port Conflict - QEMU Web Control                 ║"
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

# Читаем текущие порты
CURRENT_PORT=$(grep APP_PORT .env | cut -d '=' -f2)
CURRENT_SSL_PORT=$(grep APP_SSL_PORT .env | cut -d '=' -f2)

print_info "Current ports:"
echo "  HTTP:  $CURRENT_PORT"
echo "  HTTPS: $CURRENT_SSL_PORT"
echo ""

# Проверяем какие порты заняты
print_info "Checking which ports are in use..."
echo ""

check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Проверяем текущие порты
if check_port $CURRENT_PORT; then
    print_error "Port $CURRENT_PORT is already in use"
    
    # Показываем что использует порт
    echo ""
    echo "Process using port $CURRENT_PORT:"
    ss -tlnp 2>/dev/null | grep ":$CURRENT_PORT " || netstat -tlnp 2>/dev/null | grep ":$CURRENT_PORT " || echo "  (cannot determine)"
    echo ""
    
    PORT_CONFLICT=true
else
    print_success "Port $CURRENT_PORT is free"
    PORT_CONFLICT=false
fi

if check_port $CURRENT_SSL_PORT; then
    print_error "Port $CURRENT_SSL_PORT is already in use"
    
    echo ""
    echo "Process using port $CURRENT_SSL_PORT:"
    ss -tlnp 2>/dev/null | grep ":$CURRENT_SSL_PORT " || netstat -tlnp 2>/dev/null | grep ":$CURRENT_SSL_PORT " || echo "  (cannot determine)"
    echo ""
    
    SSL_PORT_CONFLICT=true
else
    print_success "Port $CURRENT_SSL_PORT is free"
    SSL_PORT_CONFLICT=false
fi

if [ "$PORT_CONFLICT" = false ] && [ "$SSL_PORT_CONFLICT" = false ]; then
    print_success "No port conflicts detected"
    echo ""
    print_info "You can start the application:"
    echo "  docker compose up -d"
    exit 0
fi

# Есть конфликт портов
echo ""
print_warning "Port conflict detected!"
echo ""
echo "Solutions:"
echo ""
echo "1) Change application ports (recommended)"
echo "2) Stop the process using the port"
echo "3) Find free ports automatically"
echo ""
read -p "Select option [1-3]: " option

case $option in
    1)
        print_info "Changing application ports..."
        echo ""
        
        # Предлагаем новые порты
        NEW_PORT=8081
        NEW_SSL_PORT=8444
        
        # Ищем свободный HTTP порт
        while check_port $NEW_PORT; do
            NEW_PORT=$((NEW_PORT + 1))
        done
        
        # Ищем свободный HTTPS порт
        while check_port $NEW_SSL_PORT; do
            NEW_SSL_PORT=$((NEW_SSL_PORT + 1))
        done
        
        echo "Suggested free ports:"
        echo "  HTTP:  $NEW_PORT"
        echo "  HTTPS: $NEW_SSL_PORT"
        echo ""
        
        read -p "Use these ports? [Y/n]: " use_suggested
        use_suggested=${use_suggested:-Y}
        
        if [[ "$use_suggested" =~ ^[Yy]$ ]]; then
            # Обновляем .env
            sed -i "s/APP_PORT=.*/APP_PORT=$NEW_PORT/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=$NEW_SSL_PORT/" .env
            
            print_success "Ports updated in .env"
            echo "  HTTP:  $CURRENT_PORT → $NEW_PORT"
            echo "  HTTPS: $CURRENT_SSL_PORT → $NEW_SSL_PORT"
            echo ""
            
            # Перезапускаем контейнеры
            print_info "Restarting containers with new ports..."
            docker compose down 2>/dev/null
            docker compose up -d
            
            if [ $? -eq 0 ]; then
                print_success "Containers started successfully!"
                echo ""
                echo "Access the application:"
                IP=$(hostname -I | awk '{print $1}')
                echo "  HTTP:  http://$IP:$NEW_PORT"
                echo "  HTTPS: https://$IP:$NEW_SSL_PORT"
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
            echo ""
            read -p "Enter HTTP port: " custom_port
            read -p "Enter HTTPS port: " custom_ssl_port
            
            if check_port $custom_port; then
                print_error "Port $custom_port is still in use!"
                exit 1
            fi
            
            if check_port $custom_ssl_port; then
                print_error "Port $custom_ssl_port is still in use!"
                exit 1
            fi
            
            sed -i "s/APP_PORT=.*/APP_PORT=$custom_port/" .env
            sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=$custom_ssl_port/" .env
            
            print_success "Ports updated"
            
            print_info "Restarting containers..."
            docker compose down 2>/dev/null
            docker compose up -d
        fi
        ;;
        
    2)
        print_warning "Stopping process using the port..."
        echo ""
        
        if [ "$PORT_CONFLICT" = true ]; then
            echo "Process using port $CURRENT_PORT:"
            PID=$(ss -tlnp 2>/dev/null | grep ":$CURRENT_PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
            
            if [ -z "$PID" ]; then
                PID=$(netstat -tlnp 2>/dev/null | grep ":$CURRENT_PORT " | awk '{print $7}' | cut -d'/' -f1 | head -1)
            fi
            
            if [ -n "$PID" ]; then
                PROCESS=$(ps -p $PID -o comm= 2>/dev/null)
                echo "  PID: $PID"
                echo "  Process: $PROCESS"
                echo ""
                
                read -p "Kill this process? [y/N]: " kill_process
                if [[ "$kill_process" =~ ^[Yy]$ ]]; then
                    sudo kill $PID
                    sleep 1
                    
                    if check_port $CURRENT_PORT; then
                        print_warning "Process still running, trying force kill..."
                        sudo kill -9 $PID
                        sleep 1
                    fi
                    
                    if check_port $CURRENT_PORT; then
                        print_error "Failed to stop process"
                    else
                        print_success "Process stopped"
                    fi
                fi
            else
                print_error "Cannot determine PID"
            fi
        fi
        
        echo ""
        print_info "Trying to start containers..."
        docker compose up -d
        ;;
        
    3)
        print_info "Finding free ports automatically..."
        
        # Начинаем с 8080 и ищем первый свободный
        TEST_PORT=8080
        while check_port $TEST_PORT && [ $TEST_PORT -lt 9000 ]; do
            TEST_PORT=$((TEST_PORT + 1))
        done
        
        TEST_SSL_PORT=8443
        while check_port $TEST_SSL_PORT && [ $TEST_SSL_PORT -lt 9000 ]; do
            TEST_SSL_PORT=$((TEST_SSL_PORT + 1))
        done
        
        echo ""
        print_success "Found free ports:"
        echo "  HTTP:  $TEST_PORT"
        echo "  HTTPS: $TEST_SSL_PORT"
        echo ""
        
        sed -i "s/APP_PORT=.*/APP_PORT=$TEST_PORT/" .env
        sed -i "s/APP_SSL_PORT=.*/APP_SSL_PORT=$TEST_SSL_PORT/" .env
        
        print_success "Ports updated in .env"
        
        print_info "Starting containers..."
        docker compose down 2>/dev/null
        docker compose up -d
        
        if [ $? -eq 0 ]; then
            print_success "Containers started!"
            echo ""
            IP=$(hostname -I | awk '{print $1}')
            echo "Access: http://$IP:$TEST_PORT"
        fi
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_info "Useful commands:"
echo "  docker compose ps              # Check status"
echo "  docker compose logs -f         # View logs"
echo "  ./scripts/full-diagnostic.sh           # Full diagnostic"
echo ""
