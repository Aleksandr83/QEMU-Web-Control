# Справочник команд QEMU Web Control

## Скрипты управления

### install.sh - Установка приложения

```bash
# Установка с автоопределением языка
./install.sh

# Установка на русском
./install.sh --lang ru

# Установка на английском
./install.sh --lang en
```

**Что делает:**
- Проверяет и устанавливает Docker
- Настраивает .env файл
- Выбор Docker или внешней БД
- Генерирует SSL сертификаты
- Собирает Docker контейнеры
- Устанавливает зависимости (Composer, NPM)
- Запускает миграции и сидеры
- Исправляет права доступа

---

### start.sh - Запуск приложения

```bash
# Запуск
./start.sh

# Запуск с русским языком
./start.sh --lang ru
```

**Что делает:**
- Запускает все Docker контейнеры
- Показывает URL для доступа

---

### stop.sh - Остановка приложения

```bash
# Остановка
./stop.sh

# Остановка с русским языком
./stop.sh --lang ru
```

**Что делает:**
- Останавливает все Docker контейнеры
- Сохраняет данные в БД

---

### restart.sh - Перезапуск приложения

```bash
# Перезапуск
./restart.sh

# Перезапуск с русским языком
./restart.sh --lang ru
```

**Что делает:**
- Перезапускает все Docker контейнеры
- Показывает URL для доступа

---

### uninstall.sh - Удаление приложения

```bash
# Удаление (сохраняет файлы проекта)
./uninstall.sh

# Полное удаление
./uninstall.sh --clean

# С русским языком
./uninstall.sh --clean --lang ru
```

**Опции:**
- `--clean` - удаляет также файлы проекта
- `--lang` - язык сообщений (en/ru)

**Что делает:**
- Останавливает контейнеры
- Удаляет контейнеры
- Удаляет volumes
- Удаляет images
- Опционально удаляет файлы проекта

---

### setup-database.sh - Настройка базы данных

```bash
# Запуск
./scripts/setup-database.sh
```

**Что делает:**
1. Читает конфигурацию из `.env`
2. Проверяет подключение к MySQL
3. Проверяет/создает пользователя
4. Проверяет/создает базу данных
5. Назначает права
6. Проверяет доступ пользователя к БД
7. Показывает список всех БД

**Использование:**
- При первой установке, если `install.sh` не создал БД
- После изменения параметров БД в `.env`
- Для переустановки БД
- Для диагностики проблем с БД

**Подробнее:** См. [DATABASE-TROUBLESHOOTING.RU.md](DATABASE-TROUBLESHOOTING.RU.md)

---

### fix-database-riscv.sh - Исправление MariaDB для RISC-V

```bash
# Запуск (только для RISC-V)
./scripts/fix-database-riscv.sh
```

**Интерактивное меню:**
1. Установить MariaDB на хост-системе (рекомендуется)
2. Использовать docker-compose без БД контейнера
3. Использовать PostgreSQL (экспериментально)
4. Использовать SQLite (легковесный вариант)

**Когда использовать:**
- Ошибка `no matching manifest for linux/riscv64` для MariaDB
- Контейнер `db` не запускается на RISC-V
- Нужно быстро запустить проект без Docker БД

**Автоматические действия:**
- Создает бэкап docker-compose.yml
- Устанавливает БД на хост (опция 1)
- Переключает на docker/docker-compose.riscv.yml
- Обновляет .env для подключения к хост-БД
- Запускает setup-database.sh для создания БД

**Подробнее:** См. [RISCV.RU.md](RISCV.RU.md) раздел "MariaDB не запускается"

---

### fix-nodejs-riscv.sh - Исправление Node.js для RISC-V

```bash
# Запуск (только для RISC-V)
./scripts/fix-nodejs-riscv.sh
```

**Интерактивное меню:**
1. Использовать упрощенный Dockerfile (рекомендуется - быстро)
2. Установить Node.js на хост-системе (для разработки)
3. Попытаться исправить текущий Dockerfile (экспериментально)
4. Пропустить установку Node.js (только API режим)

**Когда использовать:**
- Ошибка `ERROR 404: Not Found` при установке Node.js
- Проблемы с unofficial-builds.nodejs.org
- Долгая сборка Docker образа с Node.js
- Нужно быстро запустить проект на RISC-V

**Автоматические действия:**
- Создает бэкап текущего Dockerfile
- Пересобирает Docker образы
- Проверяет успешность установки Node.js
- Восстанавливает бэкап при неудаче

**Подробнее:** См. [RISCV.RU.md](RISCV.RU.md) раздел "Node.js не устанавливается"

---

### scripts/autostart-service.sh - Управление автозапуском

```bash
# Установить службу автозапуска
./scripts/autostart-service.sh --install --lang ru

# Проверить статус
./scripts/autostart-service.sh --status --lang ru

# Удалить службу
./scripts/autostart-service.sh --uninstall --lang ru
```

**Команды:**
- `--install` - установить службу systemd
- `--uninstall` - удалить службу
- `--status` - показать статус службы
- `--help` - справка

---

## Artisan команды

### vm:autostart - Автозапуск ВМ

```bash
# Запустить все ВМ с автозапуском
docker compose exec app php artisan vm:autostart
```

**Что делает:**
- Находит все ВМ с `autostart = true`
- Запускает остановленные ВМ
- Показывает статистику запуска

---

### key:generate - Генерация ключа

```bash
docker compose exec app php artisan key:generate
```

---

### migrate - Запуск миграций

```bash
# Применить миграции
docker compose exec app php artisan migrate

# Откатить последнюю миграцию
docker compose exec app php artisan migrate:rollback

# Сбросить и применить заново
docker compose exec app php artisan migrate:fresh

# С сидерами
docker compose exec app php artisan migrate:fresh --seed
```

---

### db:seed - Заполнение БД

```bash
# Запустить все сидеры
docker compose exec app php artisan db:seed

# Запустить конкретный сидер
docker compose exec app php artisan db:seed --class=DatabaseSeeder
```

---

### storage:link - Символическая ссылка

```bash
docker compose exec app php artisan storage:link
```

---

### cache:clear - Очистка кэша

```bash
# Очистить application cache
docker compose exec app php artisan cache:clear

# Очистить config cache
docker compose exec app php artisan config:clear

# Очистить route cache
docker compose exec app php artisan route:clear

# Очистить view cache
docker compose exec app php artisan view:clear

# Очистить всё
docker compose exec app php artisan optimize:clear
```

---

### tinker - Интерактивная консоль

```bash
docker compose exec app php artisan tinker
```

**Примеры использования:**

```php
// Посмотреть всех пользователей
User::all();

// Найти ВМ с автозапуском
VirtualMachine::where('autostart', true)->get();

// Создать нового пользователя
User::create([
    'name' => 'Test User',
    'email' => 'test@example.com',
    'password' => Hash::make('password')
]);
```

---

## Docker Compose команды

### Базовые команды

```bash
# Запустить контейнеры
docker compose up -d

# Остановить контейнеры
docker compose stop

# Перезапустить контейнеры
docker compose restart

# Остановить и удалить контейнеры
docker compose down

# Просмотр логов
docker compose logs

# Следить за логами
docker compose logs -f

# Логи конкретного сервиса
docker compose logs app
docker compose logs nginx
docker compose logs db
```

---

### Выполнение команд в контейнерах

```bash
# Войти в bash контейнера app
docker compose exec app bash

# Выполнить команду в контейнере
docker compose exec app [команда]

# Выполнить команду без TTY (для скриптов)
docker compose exec -T app [команда]
```

---

### Управление контейнерами

```bash
# Пересобрать контейнеры
docker compose build

# Пересобрать без кэша
docker compose build --no-cache

# Запустить конкретный сервис
docker compose up -d app

# Посмотреть статус контейнеров
docker compose ps

# Посмотреть использование ресурсов
docker compose stats
```

---

## NPM команды

### Разработка

```bash
# Установить зависимости
docker compose exec app npm install

# Запустить dev server
docker compose exec app npm run dev

# Собрать для продакшена
docker compose exec app npm run build
```

---

## Composer команды

```bash
# Установить зависимости
docker compose exec app composer install

# Обновить зависимости
docker compose exec app composer update

# Установить пакет
docker compose exec app composer require vendor/package

# Удалить пакет
docker compose exec app composer remove vendor/package

# Показать установленные пакеты
docker compose exec app composer show
```

---

## Работа с базой данных

### Подключение к MariaDB

```bash
# Войти в консоль БД
docker compose exec db mysql -u root -p

# Войти от имени пользователя приложения
docker compose exec db mysql -u qemu_user -p qemu_control
```

### Экспорт БД

```bash
# Экспорт всей БД
docker compose exec db mysqldump -u root -p qemu_control > backup.sql

# Экспорт с сжатием
docker compose exec db mysqldump -u root -p qemu_control | gzip > backup.sql.gz
```

### Импорт БД

```bash
# Импорт из файла
docker compose exec -T db mysql -u root -p qemu_control < backup.sql

# Импорт из архива
gunzip < backup.sql.gz | docker compose exec -T db mysql -u root -p qemu_control
```

---

## Системные команды

### Права доступа

```bash
# Исправить права (из install.sh)
sudo chown -R 1000:1000 vendor node_modules storage bootstrap/cache public
chmod -R 775 storage bootstrap/cache
```

### SSL сертификаты

```bash
# Сгенерировать новый сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout docker/nginx/ssl/server.key \
    -out docker/nginx/ssl/server.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=QEMU/CN=localhost"

# Проверить сертификат
openssl x509 -in docker/nginx/ssl/server.crt -text -noout
```

### Логи

```bash
# Laravel логи
tail -f storage/logs/laravel.log

# Nginx логи
docker compose logs -f nginx

# PHP-FPM логи
docker compose logs -f app

# MariaDB логи
docker compose logs -f db

# Все логи
docker compose logs -f
```

---

## Полезные команды

### Проверка системы

```bash
# Проверить версию PHP
docker compose exec app php -v

# Проверить версию Laravel
docker compose exec app php artisan --version

# Проверить подключение к БД
docker compose exec app php artisan tinker
>>> DB::connection()->getPdo();

# Проверить статус миграций
docker compose exec app php artisan migrate:status
```

### Очистка системы

```bash
# Очистить неиспользуемые Docker образы
docker system prune -a

# Очистить volumes
docker volume prune

# Очистить Laravel кэши
docker compose exec app php artisan optimize:clear
```

### Диагностика

```bash
# Проверить конфигурацию Laravel
docker compose exec app php artisan config:show

# Проверить маршруты
docker compose exec app php artisan route:list

# Проверить планировщик задач
docker compose exec app php artisan schedule:list

# Информация о приложении
docker compose exec app php artisan about
```

---

## Быстрые команды (alias)

Добавьте в `~/.bashrc` или `~/.zshrc`:

```bash
# Алиасы для QEMU Web Control
alias qemu-start='cd /path/to/QemuWebControl && ./start.sh'
alias qemu-stop='cd /path/to/QemuWebControl && ./stop.sh'
alias qemu-restart='cd /path/to/QemuWebControl && ./restart.sh'
alias qemu-logs='cd /path/to/QemuWebControl && docker compose logs -f'
alias qemu-shell='cd /path/to/QemuWebControl && docker compose exec app bash'
alias qemu-tinker='cd /path/to/QemuWebControl && docker compose exec app php artisan tinker'
alias qemu-migrate='cd /path/to/QemuWebControl && docker compose exec app php artisan migrate'
```

После добавления:

```bash
source ~/.bashrc
```

---

## Автообновление Let's Encrypt

После импорта сертификата Let's Encrypt через Настройки > Сертификаты добавьте в crontab:

```bash
crontab -e
# Добавьте (замените путь на ваш проект):
0 3 * * * certbot renew --quiet --deploy-hook "/путь/к/QemuWebControl/scripts/renew-letsencrypt-deploy-hook.sh"
```

Скрипт копирует обновлённые сертификаты в nginx и перезагружает его. Требуется certbot на хосте:

```bash
sudo apt install certbot
```

Ручное копирование после certbot renew:

```bash
docker compose exec app php artisan certificates:renew
docker compose exec nginx nginx -s reload
```

---

## Troubleshooting команды

### Контейнеры не запускаются

```bash
# Проверить статус Docker
sudo systemctl status docker

# Перезапустить Docker
sudo systemctl restart docker

# Проверить логи Docker
sudo journalctl -u docker -n 100
```

### Ошибки БД

```bash
# Проверить доступность БД
docker compose exec app php artisan db:show

# Пересоздать БД
docker compose exec app php artisan migrate:fresh --seed
```

### Проблемы с правами

```bash
# Проверить владельца файлов
ls -la storage/
ls -la vendor/

# Исправить права
sudo chown -R 1000:1000 storage bootstrap/cache vendor node_modules
chmod -R 775 storage bootstrap/cache
```

### Очистка и перезапуск

```bash
# Полная очистка и перезапуск
docker compose down -v
docker compose build --no-cache
./install.sh
```

---

## Документация

- [README.md](README.md) - Основная документация (EN)
- [README.RU.md](../../README.RU.md) - Основная документация (RU)
- [INSTALL.RU.md](INSTALL.RU.md) / [INSTALL.EN.md](../EN/INSTALL.EN.md) - Быстрая установка
- [AUTOSTART.EN.md](../EN/AUTOSTART.EN.md) / [AUTOSTART.RU.md](AUTOSTART.RU.md) - Руководство по автозапуску (EN/RU)
- [COMMANDS.EN.md](../EN/COMMANDS.EN.md) - Справочник команд (EN)
- [COMMANDS.RU.md](COMMANDS.RU.md) - Этот файл (RU)
- [CHANGELOG.EN.md](../EN/CHANGELOG.EN.md) / [CHANGELOG.RU.md](CHANGELOG.RU.md) - История изменений (EN/RU)
- [TROUBLESHOOTING.EN.md](../EN/TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](TROUBLESHOOTING.RU.md) - Устранение проблем (EN/RU)

---

**Совет**: Добавьте этот файл в закладки для быстрого доступа к командам!
