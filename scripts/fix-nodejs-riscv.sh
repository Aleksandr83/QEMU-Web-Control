#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"


echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           Fix Node.js Installation for RISC-V - Quick Script            ║"
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

# Меню выбора
echo "Choose Node.js installation method:"
echo ""
echo "1) Use simplified Dockerfile (recommended - fast)"
echo "2) Install Node.js on host system (development)"
echo "3) Try to fix current Dockerfile (experimental)"
echo "4) Skip Node.js installation (API only mode)"
echo ""
read -p "Select option [1-4]: " option

case $option in
    1)
        print_info "Using simplified Dockerfile..."
        
        if [ ! -f docker/php/Dockerfile.riscv-simple ]; then
            print_error "docker/php/Dockerfile.riscv-simple not found!"
            exit 1
        fi
        
        # Бэкап текущего Dockerfile
        if [ -f docker/php/Dockerfile ]; then
            cp docker/php/Dockerfile docker/php/Dockerfile.backup
            print_success "Backed up current Dockerfile to Dockerfile.backup"
        fi
        
        # Копируем упрощенный
        cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile
        print_success "Copied simplified Dockerfile"
        
        # Пересборка
        print_info "Rebuilding Docker images (this may take 10-20 minutes)..."
        docker compose down
        docker compose build --no-cache app
        
        if [ $? -eq 0 ]; then
            print_success "Build successful!"
            
            print_info "Starting containers..."
            docker compose up -d
            
            if [ $? -eq 0 ]; then
                print_success "Containers started!"
                
                # Проверяем Node.js
                sleep 5
                print_info "Checking Node.js installation..."
                docker compose exec -T app node --version || print_warning "Node.js not available in container"
                docker compose exec -T app npm --version || print_warning "npm not available in container"
            else
                print_error "Failed to start containers"
                exit 1
            fi
        else
            print_error "Build failed"
            
            # Восстанавливаем бэкап
            if [ -f docker/php/Dockerfile.backup ]; then
                cp docker/php/Dockerfile.backup docker/php/Dockerfile
                print_info "Restored backup Dockerfile"
            fi
            exit 1
        fi
        ;;
        
    2)
        print_info "Installing Node.js on host system..."
        
        # Проверяем, не установлен ли уже
        if command -v node &> /dev/null; then
            NODE_VERSION=$(node --version)
            print_warning "Node.js already installed: $NODE_VERSION"
            read -p "Reinstall? [y/n]: " reinstall
            if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
                print_info "Skipping installation"
                exit 0
            fi
        fi
        
        # Устанавливаем из Debian репозитория
        print_info "Installing from Debian repositories..."
        sudo apt-get update
        sudo apt-get install -y nodejs npm
        
        if command -v node &> /dev/null; then
            print_success "Node.js installed: $(node --version)"
            print_success "npm installed: $(npm --version)"
            
            echo ""
            print_info "Installing project dependencies..."
            npm install
            
            echo ""
            print_success "Installation complete!"
            echo ""
            echo "To use Vite for development:"
            echo "  npm run dev"
            echo ""
            echo "To build assets:"
            echo "  npm run build"
            echo ""
        else
            print_error "Failed to install Node.js"
            
            # Пробуем альтернативный метод
            print_info "Trying alternative method (NodeSource)..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
            sudo apt-get install -y nodejs
            
            if command -v node &> /dev/null; then
                print_success "Node.js installed: $(node --version)"
            else
                print_error "Failed to install Node.js"
                exit 1
            fi
        fi
        ;;
        
    3)
        print_warning "This option will try to fix the current Dockerfile"
        print_warning "This may take a long time (30-60 minutes)"
        echo ""
        read -p "Continue? [y/n]: " continue
        
        if [[ ! "$continue" =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
        
        print_info "Rebuilding with extended timeout..."
        docker compose down
        docker compose build --no-cache app
        
        if [ $? -eq 0 ]; then
            print_success "Build successful!"
            docker compose up -d
        else
            print_error "Build failed"
            print_info "Consider using option 1 or 2"
            exit 1
        fi
        ;;
        
    4)
        print_warning "Skipping Node.js installation"
        print_info "The application will work without frontend assets"
        print_info "You can build assets later using option 2"
        
        # Просто запускаем без пересборки
        docker compose up -d
        print_success "Containers started in API-only mode"
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_success "Done!"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f app     # View logs"
echo "  docker compose exec app bash   # Enter container"
echo "  ./scripts/diagnose.sh                  # Full system diagnostic"
echo ""
