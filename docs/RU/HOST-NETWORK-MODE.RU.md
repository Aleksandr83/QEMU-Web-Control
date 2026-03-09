# Docker Host Network Mode для доступа к localhost БД

Эта конфигурация позволяет Docker контейнерам безопасно подключаться к localhost базе данных без открытия портов наружу.

## Преимущества Host Network Mode

✅ **Безопасность:** БД остается на localhost (127.0.0.1)
✅ **Производительность:** Нет NAT, прямое подключение
✅ **Простота:** `DB_HOST=localhost` работает из контейнера
✅ **Firewall:** Не нужно открывать порт 3306 наружу

## Недостатки

⚠️ **Изоляция:** Контейнеры видят все сетевые интерфейсы хоста
⚠️ **Порты:** Конфликты портов (nginx на 80, 443 вместо 8080, 8443)
⚠️ **Совместимость:** Работает только на Linux (не на Mac/Windows Docker Desktop)

## Вариант 1: Host Network Mode (рекомендуется для production)

### docker/docker-compose.host-network.yml

```yaml
services:
  app:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_app
    restart: unless-stopped
    network_mode: "host"  # <-- Ключевое изменение
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
      - ./docker/php/zz-docker.conf:/usr/local/etc/php-fpm.d/zz-docker.conf
    environment:
      - DB_HOST=localhost  # <-- Работает!
      - DB_PORT=${DB_PORT}
      - DB_DATABASE=${DB_DATABASE}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}

  nginx:
    build:
      context: ./docker/nginx
      dockerfile: Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    restart: unless-stopped
    network_mode: "host"  # <-- Ключевое изменение
    volumes:
      - ./:/var/www
      - ./docker/nginx/conf.d:/etc/nginx/conf.d
      - ./docker/nginx/ssl:/etc/nginx/ssl
    depends_on:
      - app

  scheduler:
    build:
      context: .
      dockerfile: docker/php/Dockerfile
    container_name: ${COMPOSE_PROJECT_NAME}_scheduler
    restart: unless-stopped
    network_mode: "host"  # <-- Ключевое изменение
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    entrypoint: /bin/sh
    command: -c "while true; do php /var/www/artisan schedule:run --verbose --no-interaction; sleep 60; done"
```

### Изменения в nginx конфигурации

При использовании host network mode nginx будет слушать на стандартных портах:

```nginx
# docker/nginx/conf.d/default.conf для host network
server {
    listen 80;  # Вместо 8080
    listen [::]:80;
    server_name _;
    
    root /var/www/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;  # localhost вместо app:9000
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

server {
    listen 443 ssl http2;  # Вместо 8443
    listen [::]:443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    
    root /var/www/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;  # localhost
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### Настройка .env

```env
# Безопасное подключение к localhost БД
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password

# Стандартные порты (host network mode)
APP_PORT=80
APP_SSL_PORT=443
```

### Конфигурация MariaDB (безопасная)

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf

[mysqld]
# Слушаем ТОЛЬКО на localhost - безопасно!
bind-address = 127.0.0.1

# Дополнительная безопасность
skip-name-resolve = 1
```

### Использование

```bash
# Переключиться на host network mode
cp docker/docker-compose.host-network.yml docker-compose.yml

# Обновить .env
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
sed -i 's/APP_PORT=.*/APP_PORT=80/' .env
sed -i 's/APP_SSL_PORT=.*/APP_SSL_PORT=443/' .env

# Перезапустить
docker compose down
docker compose up -d

# Проверить
docker compose exec app php artisan db:show
```

## Вариант 2: Unix Socket (максимальная безопасность)

### Преимущества Unix Socket

✅ **Самый безопасный:** Нет сетевого подключения вообще
✅ **Быстрее:** Нет TCP overhead
✅ **Простой firewall:** TCP порт не используется

### docker-compose.yml с сокетом

```yaml
services:
  app:
    # ... остальное без изменений
    volumes:
      - ./:/var/www
      - /var/run/mysqld:/var/run/mysqld  # <-- Монтируем сокет
    environment:
      - DB_HOST=/var/run/mysqld/mysqld.sock  # <-- Unix socket
```

### .env для Unix socket

```env
# Unix socket - самый безопасный вариант
DB_CONNECTION=mysql
DB_HOST=/var/run/mysqld/mysqld.sock
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

### Использование Unix socket

```bash
# Проверить что сокет существует
ls -la /var/run/mysqld/mysqld.sock

# Обновить docker-compose.yml (добавить volume)
# Обновить .env
sed -i 's|DB_HOST=.*|DB_HOST=/var/run/mysqld/mysqld.sock|' .env

# Перезапустить
docker compose down
docker compose up -d

# Проверить
docker compose exec app php artisan db:show
```

## Сравнение вариантов

| Характеристика | Bridge (default) | Host Network | Unix Socket |
|----------------|------------------|--------------|-------------|
| Безопасность БД | ⚠️ Нужен external IP | ✅ localhost | ✅✅ Нет сети |
| Изоляция | ✅ Полная | ⚠️ Нет | ✅ Полная |
| Порты | 8080, 8443 | 80, 443 | 8080, 8443 |
| Производительность | Хорошая | Отличная | Лучшая |
| Совместимость | Все ОС | Только Linux | Linux |
| Сложность | Простая | Простая | Средняя |

## Рекомендации

### Для Orange Pi (Production)

**Используйте Host Network Mode:**
```bash
cp docker/docker-compose.host-network.yml docker-compose.yml
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
```

**MariaDB конфигурация:**
```ini
bind-address = 127.0.0.1  # Безопасно!
```

**Firewall:**
```bash
# Порт 3306 закрыт наружу - не нужен!
sudo ufw deny 3306/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Для разработки

**Unix Socket:**
```bash
# Добавить в docker-compose.yml volume для сокета
# Обновить .env с путем к сокету
```

## Безопасность

### Host Network Mode

```bash
# MariaDB слушает только localhost
ss -tlnp | grep 3306
# Должно быть: 127.0.0.1:3306

# Проверка снаружи (должно fail)
mysql -h <orange_pi_ip> -u qemu_user -p
# ERROR 2002 (HY000): Can't connect to MySQL server

# Проверка изнутри (должно работать)
docker compose exec app mysql -h localhost -u qemu_user -p
# Connected!
```

### Unix Socket

```bash
# Нет сетевого порта вообще!
ss -tlnp | grep 3306
# (пусто)

# Только через сокет
docker compose exec app mysql -h /var/run/mysqld/mysqld.sock -u qemu_user -p
# Connected!
```

## Миграция с bridge на host network

```bash
# 1. Остановить текущую конфигурацию
docker compose down

# 2. Бэкап текущего compose
cp docker-compose.yml docker-compose.yml.bridge

# 3. Использовать host network
cp docker/docker-compose.host-network.yml docker-compose.yml

# 4. Обновить .env
sed -i 's/DB_HOST=.*/DB_HOST=localhost/' .env
sed -i 's/APP_PORT=.*/APP_PORT=80/' .env
sed -i 's/APP_SSL_PORT=.*/APP_SSL_PORT=443/' .env

# 5. Настроить MariaDB на localhost only
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
# bind-address = 127.0.0.1

# 6. Перезапустить
sudo systemctl restart mariadb
docker compose up -d

# 7. Проверить
curl http://localhost
docker compose exec app php artisan db:show
```

## Troubleshooting

### Конфликт портов в host network mode

Если nginx не стартует из-за занятых портов 80/443:

```bash
# Проверить что использует порты
sudo ss -tlnp | grep -E ':(80|443)'

# Остановить конфликтующий сервис
sudo systemctl stop apache2  # или nginx

# Или изменить порты в nginx конфигурации
# listen 8080; вместо listen 80;
```

### Unix socket не найден

```bash
# Проверить путь к сокету
sudo grep socket /etc/mysql/mariadb.conf.d/50-server.cnf

# Обычно:
# socket = /var/run/mysqld/mysqld.sock

# Права на директорию
sudo chmod 755 /var/run/mysqld
sudo chown mysql:mysql /var/run/mysqld/mysqld.sock
```

## Итого

**Для максимальной безопасности на Orange Pi:**

1. ✅ Используйте **host network mode**
2. ✅ MariaDB с `bind-address = 127.0.0.1`
3. ✅ Firewall блокирует порт 3306
4. ✅ `DB_HOST=localhost` в `.env`
5. ✅ Приложение доступно на стандартных портах 80/443

**Результат:** База данных полностью защищена, доступна только localhost!

---

**Языковые версии:** [HOST-NETWORK-MODE.EN.md](../EN/HOST-NETWORK-MODE.EN.md) | [HOST-NETWORK-MODE.RU.md](HOST-NETWORK-MODE.RU.md)
