# Быстрый старт на RISC-V

## Orange Pi RV2 / VisionFive / Milk-V

### Шаг 1: Подготовка системы

```bash
# Обновите систему
sudo apt update && sudo apt upgrade -y

# Установите необходимые пакеты
sudo apt install -y git curl wget

# Увеличьте swap (если RAM < 4GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Шаг 2: Установка Docker

На Orange Pi RV2 Docker устанавливается как `docker.io`:

```bash
# Обновите систему
sudo apt-get update

# Установите Docker и Docker Compose
sudo apt-get install -y docker.io docker-compose

# Запустите Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавьте пользователя в группу docker
sudo usermod -aG docker $USER

# Проверьте установку
docker --version
docker-compose --version

# Перелогиньтесь
exit
# Войдите снова по SSH
```

**Примечание**: Скрипт `install.sh` может установить Docker автоматически, если его нет.

### Шаг 3: Клонирование проекта

```bash
cd /var/www
sudo mkdir -p QemuWebControl
sudo chown -R $USER:$USER QemuWebControl
cd QemuWebControl

# Скопируйте файлы проекта сюда
```

### Шаг 4: Установка

```bash
# Запустите установку
chmod +x install.sh
./install.sh --lang ru
```

**Важно**: Установка займет 20-30 минут! Это нормально для RISC-V.

### Шаг 5: Проверка

```bash
# Проверьте статус контейнеров
docker compose ps

# Должны быть запущены:
# - qemu_app
# - qemu_nginx
# - qemu_db
# - qemu_scheduler
```

### Шаг 6: Доступ

Откройте в браузере:
- HTTP: http://your-orange-pi-ip:8080
- HTTPS: https://your-orange-pi-ip:8443

Логин: admin  
Пароль: admin

## Если что-то пошло не так

### Полная диагностика проблемы

**Запустите скрипт диагностики:**

```bash
./scripts/full-diagnostic.sh
```

Скрипт создаст детальный отчет `diagnostic-YYYYMMDD-HHMMSS.log` с:
- Системной информацией
- Конфигурацией Docker
- Статусом контейнеров
- Логами всех сервисов
- Проверкой БД
- Анализом проблем
- Рекомендациями по исправлению

**Отправьте лог разработчику или используйте для самостоятельной диагностики.**

### Node.js не устанавливается (ERROR 404)

**Быстрое решение:**

```bash
# Запустите скрипт автоматического исправления
./scripts/fix-nodejs-riscv.sh

# Выберите вариант:
# 1 - Упрощенный Dockerfile (рекомендуется)
# 2 - Установить Node.js на хост
# 3 - Попробовать исправить текущий Dockerfile
# 4 - Пропустить Node.js (только API)
```

**Ручное решение:**

```bash
# Вариант 1: Упрощенный Dockerfile
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile
docker compose down
docker compose build --no-cache app
docker compose up -d

# Вариант 2: Node.js на хосте
sudo apt-get install -y nodejs npm
npm install
npm run build
```

### MariaDB не запускается даже при выборе внешней БД

**Проблема:** 
```
no matching manifest for linux/riscv64
```

**Быстрое решение:**

```bash
# Автоматическое исправление
./scripts/quick-fix-riscv.sh

# Скрипт всё сделает автоматически
```

**Или используйте:**

```bash
# Исправить конфигурацию БД
./scripts/fix-database-riscv.sh
# Выбрать вариант 1 или 2
```

### MariaDB не запускается

**Причина:** Нет образа MariaDB для RISC-V

**Быстрое решение:**

```bash
# Используйте скрипт автоматического исправления
./scripts/fix-database-riscv.sh

# Рекомендуется выбрать вариант 1:
# Установить MariaDB на хост-систему
```

**Ручное решение:**

```bash
# Остановите контейнеры
docker compose down

# Установите MariaDB на хост
sudo apt install -y mariadb-server

# Настройте MariaDB
sudo mysql_secure_installation

# Создайте БД и пользователя
sudo mysql -u root -p
```

В MySQL консоли:
```sql
CREATE DATABASE qemu_control;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Отредактируйте `.env`:
```bash
nano .env
```

Измените:
```env
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

Перезапустите:
```bash
./start.sh --lang ru
```

### NPM ошибки

Если NPM не работает:

```bash
# Войдите в контейнер
docker compose exec app bash

# Проверьте Node.js
node --version
npm --version

# Если не найден, переустановите образ
exit
docker compose down
docker compose build --no-cache app
docker compose up -d
```

### Медленная работа

Оптимизация:

```bash
# Остановите ненужные сервисы
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth

# Очистите кэш
sudo apt clean
docker system prune -a

# Перезапустите
sudo reboot
```

## Рекомендуемые настройки для ВМ на RISC-V

При создании виртуальных машин:

- **CPU**: 1 ядро (максимум 2)
- **RAM**: 512 MB (максимум 1024 MB)
- **Диск**: 10 GB (максимум 20 GB)
- **Сеть**: User (NAT)
- **VNC**: Не использовать (медленно)

## Мониторинг

```bash
# Использование ресурсов
htop

# Статус Docker
docker stats

# Логи приложения
docker compose logs -f app
```

## Полезные команды

```bash
# Перезапуск
./restart.sh --lang ru

# Остановка
./stop.sh --lang ru

# Логи
docker compose logs -f

# Вход в контейнер
docker compose exec app bash

# Проверка БД
docker compose exec app php artisan db:show
```

## Производительность

Ожидаемое время выполнения на Orange Pi RV2:

| Операция | Время |
|----------|-------|
| Сборка образов | 15-25 мин |
| Composer install | 3-5 мин |
| NPM install | 5-10 мин |
| NPM build | 2-4 мин |
| Запуск ВМ | 5-15 сек |
| Загрузка страницы | 1-3 сек |

## Поддержка

Подробная документация: [RISCV.EN.md](../EN/RISCV.EN.md) / [RISCV.RU.md](RISCV.RU.md)

Общая документация: [README.RU.md](../../README.RU.md)

---

**Языковые версии:** [RISCV-QUICKSTART.EN.md](../EN/RISCV-QUICKSTART.EN.md) | [RISCV-QUICKSTART.RU.md](RISCV-QUICKSTART.RU.md)
