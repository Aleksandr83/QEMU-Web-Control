# Установка на RISC-V архитектуру

## Особенности установки на RISC-V (Orange Pi, VisionFive и др.)

Проект адаптирован для работы на RISC-V архитектуре с некоторыми особенностями.

## Требования

- Linux RISC-V (протестировано на Orange Pi RV2)
- Docker с поддержкой RISC-V
- QEMU для RISC-V (если планируется запуск ВМ)

## Установка Docker на RISC-V

На RISC-V системах (Orange Pi RV2, VisionFive и др.) Docker устанавливается из репозитория как `docker.io`:

```bash
# Обновите систему
sudo apt-get update

# Установите Docker и Docker Compose
sudo apt-get install -y docker.io docker-compose

# Запустите и включите Docker
sudo systemctl start docker
sudo systemctl enable docker

# Добавьте пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогиньтесь для применения изменений
exit
# Войдите снова
```

**Примечание**: Скрипт `install.sh` автоматически определяет RISC-V и использует правильный метод установки.

## Особенности Docker образов

### MariaDB
На RISC-V используется последняя версия MariaDB с явным указанием платформы:
```yaml
db:
  image: mariadb:latest
  platform: linux/riscv64
```

### Nginx
Nginx собирается из Alpine образа, который поддерживает RISC-V:
```yaml
nginx:
  build:
    context: ./docker/nginx
    dockerfile: Dockerfile
```

### PHP-FPM
PHP 8.3-FPM с автоматической установкой Node.js для RISC-V:
- Node.js устанавливается из нескольких источников с fallback
- Приоритет: NodeSource → unofficial-builds → Debian → сборка из исходников
- Версия: 20.x LTS (последняя доступная для RISC-V)

#### Проблема с Node.js на RISC-V

Некоторые версии Node.js могут быть недоступны для RISC-V. Dockerfile использует несколько запасных вариантов:

1. **NodeSource репозиторий** (самый надежный)
2. **Unofficial builds** v20.18.1, v20.11.1
3. **Debian репозитории** (стабильная, но старая версия)
4. **Сборка из исходников** (медленно, но надежно)

Если все равно возникают проблемы, используйте упрощенную версию:

```bash
# Скопируйте упрощенный Dockerfile
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile

# Пересоберите образ
docker compose build --no-cache app
```

**Альтернатива:** Запустите Vite на хосте вместо Docker:

```bash
# На хосте установите Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# Запустите приложение без Vite в Docker
docker compose up -d

# На хосте установите зависимости и запустите Vite
npm install
npm run dev
```

## Установка

```bash
# Стандартная установка
./install.sh --lang ru
```

Процесс установки может занять больше времени на RISC-V из-за:
- Сборки образов (особенно PHP с Node.js)
- Более медленной архитектуры по сравнению с x86_64

## Возможные проблемы

### 1. Docker не устанавливается через get.docker.com

**Проблема:**
```
Package 'docker-ce' has no installation candidate
```

**Решение:**
На RISC-V используйте `docker.io` из репозитория:
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
```

Скрипт `install.sh` автоматически определяет RISC-V и использует правильный метод.

### 3. Node.js не устанавливается

**Проблема:**
```
ERROR 404: Not Found
# или
wget: unable to resolve host address 'unofficial-builds.nodejs.org'
```

**Причина:**
Файлы Node.js для RISC-V могут быть недоступны или репозиторий недоступен.

**Решение 1: Использовать упрощенный Dockerfile**

```bash
# Остановите контейнеры
docker compose down

# Используйте упрощенную версию
cp docker/php/Dockerfile.riscv-simple docker/php/Dockerfile

# Пересоберите
docker compose build --no-cache app
docker compose up -d
```

**Решение 2: Установить Node.js на хосте**

```bash
# Установите Node.js на хост-системе
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs

# Проверьте версию
node --version
npm --version

# Измените docker-compose.yml, удалив npm команды
# Запустите приложение
docker compose up -d

# Установите зависимости на хосте
npm install
npm run build

# Для разработки запустите Vite на хосте
npm run dev
```

**Решение 3: Собрать Node.js из исходников (долго, ~30-60 минут)**

```bash
# На хосте или в контейнере
wget https://nodejs.org/dist/v20.11.1/node-v20.11.1.tar.gz
tar -xf node-v20.11.1.tar.gz
cd node-v20.11.1
./configure
make -j$(nproc)
sudo make install
```

### 4. Ошибка "no matching manifest"

**Проблема:**
```
no matching manifest for linux/riscv64 in the manifest list entries
```

**Решение:**
Убедитесь, что используете обновленную версию docker-compose.yml с поддержкой RISC-V.

Проверьте, что в docker-compose.yml:
- Nginx собирается из Dockerfile
- MariaDB использует `platform: linux/riscv64`
- PHP собирается с ручной установкой Node.js

### 5. docker-compose: command not found

**Проблема:**
```
docker-compose: command not found
```

**Решение:**
Установите docker-compose:
```bash
sudo apt-get install -y docker-compose
```

Или используйте встроенную команду Docker:
```bash
# Вместо docker-compose используйте:
docker compose up -d
docker compose down
docker compose logs
```

### 6. Медленная сборка образов

**Проблема:** Сборка PHP образа занимает 10-20 минут

**Решение:** Это нормально для RISC-V. Дождитесь завершения сборки.

### 7. Node.js не найден

**Проблема:**
```
npm: command not found
```

**Решение:**
Проверьте, что Node.js установлен в контейнере:
```bash
docker compose exec app node --version
docker compose exec app npm --version
```

Если не установлен, используйте решения из раздела "3. Node.js не устанавливается" выше.

### 8. MariaDB не запускается даже при выборе внешней БД

**Проблема:** Выбрали внешнюю БД при установке, но всё равно получаете:
```
no matching manifest for linux/riscv64 in the manifest list entries
```

**Причина:** В старых версиях `install.sh` не переключал `docker-compose.yml` на версию без БД контейнера для RISC-V.

**Быстрое решение:**

```bash
# Автоматическое исправление текущей установки
./scripts/quick-fix-riscv.sh
```

Скрипт автоматически:
- Проверит конфигурацию БД
- Переключит на docker/docker-compose.riscv.yml
- Перезапустит контейнеры
- Проверит подключение к БД
- Запустит миграции если нужно

**Ручное решение:**

```bash
# 1. Остановите контейнеры
docker compose down

# 2. Переключите docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
cp docker/docker-compose.riscv.yml docker-compose.yml

# 3. Проверьте .env
nano .env
# Убедитесь что DB_HOST=localhost (не db)

# 4. Создайте БД если не создалась
./scripts/setup-database.sh

# 5. Запустите контейнеры
docker compose up -d

# 6. Запустите миграции
docker compose exec app php artisan migrate --seed
```

### 9. MariaDB контейнер пытается запуститься

**Проблема:** Контейнер db постоянно перезапускается

**Причина:** MariaDB не имеет официального образа для RISC-V

**Быстрое решение:**

```bash
# Автоматическое исправление
./scripts/fix-database-riscv.sh

# Выберите вариант:
# 1 - Установить MariaDB на хост (рекомендуется)
# 2 - Использовать docker-compose без БД
# 3 - Использовать PostgreSQL
# 4 - Использовать SQLite (легковесный вариант)
```

**Ручное решение (MariaDB на хосте):**

```bash
# Установите MariaDB на хост
sudo apt-get update
sudo apt-get install -y mariadb-server mariadb-client

# Запустите MariaDB
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Смените docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup
cp docker/docker-compose.riscv.yml docker-compose.yml

# Обновите .env
nano .env
# Измените: DB_HOST=localhost

# Создайте БД
./scripts/setup-database.sh

# Запустите контейнеры
docker compose up -d
```

## Производительность

### Ожидаемая производительность на Orange Pi RV2:

- **Сборка образов**: 15-25 минут
- **Запуск контейнеров**: 30-60 секунд
- **Composer install**: 3-5 минут
- **NPM install**: 5-10 минут
- **NPM build**: 2-4 минуты

### Оптимизация:

1. **Используйте внешнюю БД** вместо Docker контейнера
2. **Увеличьте swap** если мало RAM:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

3. **Отключите ненужные сервисы** для освобождения ресурсов

## QEMU на RISC-V

### Установка QEMU

```bash
sudo apt-get install qemu-system-x86 qemu-system-arm qemu-utils
```

### Особенности:

- QEMU на RISC-V работает через эмуляцию
- Производительность ВМ будет ниже чем на x86_64
- Рекомендуется использовать для легких ВМ

### Рекомендуемые настройки ВМ:

- **CPU**: 1-2 ядра (больше не имеет смысла)
- **RAM**: 512-1024 MB
- **Диск**: 10-20 GB
- **Сеть**: user (NAT)

## Альтернативные варианты

### Вариант 1: Использование внешней БД

```bash
# Установите MariaDB на хост
sudo apt-get install mariadb-server

# Настройте доступ
sudo mysql_secure_installation

# При установке выберите External DB
./install.sh --lang ru
```

### Вариант 2: Использование SQLite (легковесный)

Если MariaDB работает медленно, можно использовать SQLite:

1. Измените `.env`:
```env
DB_CONNECTION=sqlite
DB_DATABASE=/var/www/database/database.sqlite
```

2. Создайте файл БД:
```bash
touch database/database.sqlite
chmod 664 database/database.sqlite
```

3. Запустите миграции:
```bash
docker compose exec app php artisan migrate --seed
```

## Мониторинг ресурсов

```bash
# Использование ресурсов контейнерами
docker stats

# Использование ресурсов системы
htop

# Использование диска
df -h
```

## Рекомендации для RISC-V

1. **Минимальные требования**:
   - 2 GB RAM (4 GB рекомендуется)
   - 10 GB свободного места
   - 2-4 ядра CPU

2. **Оптимальная конфигурация**:
   - Внешняя MariaDB на хосте
   - Swap 2-4 GB
   - Отключенные ненужные сервисы

3. **Не рекомендуется**:
   - Запуск более 2-3 ВМ одновременно
   - ВМ с более чем 2 ядрами CPU
   - ВМ с более чем 2 GB RAM

## Поддержка

При проблемах на RISC-V:

1. Проверьте логи:
```bash
docker compose logs
```

2. Проверьте архитектуру:
```bash
uname -m  # Должно быть riscv64
```

3. Проверьте Docker:
```bash
docker version
docker info | grep Architecture
```

4. Используйте внешнюю БД если Docker DB не работает

## Известные ограничения

1. **Node.js**: Используется unofficial build, может быть нестабильным
2. **MariaDB**: Может работать медленнее чем на x86_64
3. **QEMU**: Эмуляция x86 ВМ будет медленной
4. **NPM**: Некоторые пакеты могут не иметь prebuilt бинарников для RISC-V

## Успешно протестировано на:

- ✅ Orange Pi RV2 (Allwinner D1)
- ⚠️ VisionFive 2 (частично)
- ⚠️ Milk-V Mars (частично)

## Обратная связь

Если вы успешно запустили на другой RISC-V платформе, пожалуйста, сообщите нам!

---

**Языковые версии:** [RISCV.EN.md](../EN/RISCV.EN.md) | [RISCV.RU.md](RISCV.RU.md)
