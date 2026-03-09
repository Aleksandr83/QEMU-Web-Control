# Руководство по устранению проблем

## Реалистичный подход к установке

На практике, особенно на RISC-V, могут возникнуть различные проблемы. Это руководство поможет их решить.

## Чеклист после установки

### 1. Проверка Docker

```bash
# Проверьте, что Docker запущен
sudo systemctl status docker

# Если не запущен
sudo systemctl start docker
sudo systemctl enable docker

# Проверьте версию
docker --version
docker compose version
# или
docker-compose --version
```

### 2. Проверка контейнеров

```bash
# Посмотрите статус контейнеров
docker compose ps
# или
docker-compose ps

# Должны быть запущены (Up):
# - qemu_app
# - qemu_nginx
# - qemu_db (если используете Docker БД)
# - qemu_scheduler
```

**Если контейнеры не запущены:**

```bash
# Посмотрите логи
docker compose logs
# или конкретного контейнера
docker compose logs app
docker compose logs nginx
docker compose logs db

# Попробуйте пересобрать
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 3. Проверка базы данных

```bash
# Если используете Docker БД
docker compose exec db mysql -u root -p

# Если внешняя БД
mysql -h localhost -u qemu_user -p qemu_control
```

**Проверьте, что база создана:**

```sql
SHOW DATABASES;
USE qemu_control;
SHOW TABLES;
```

**Если база не создана:**

```bash
# Создайте вручную
sudo mysql -u root -p

CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
FLUSH PRIVILEGES;
EXIT;

# Запустите миграции
docker compose exec app php artisan migrate --seed
```

### 4. Проверка прав доступа

```bash
# Проверьте владельца файлов
ls -la storage/
ls -la bootstrap/cache/
ls -la vendor/

# Если права неправильные
sudo chown -R 1000:1000 storage bootstrap/cache vendor node_modules
chmod -R 775 storage bootstrap/cache
```

### 5. Проверка доступа к приложению

```bash
# Проверьте, что Nginx отвечает
curl http://localhost:8080

# Если ошибка, проверьте логи
docker compose logs nginx
docker compose logs app
```

## Типичные проблемы

### Проблема 1: "Connection refused" при доступе к сайту

**Причина:** Контейнеры не запущены или порты заняты

**Решение:**

```bash
# Проверьте, что контейнеры запущены
docker compose ps

# Проверьте, не занят ли порт
sudo netstat -tlnp | grep 8080
sudo netstat -tlnp | grep 8443

# Если порт занят, измените в .env
nano .env
# Измените APP_PORT и APP_SSL_PORT

# Перезапустите
docker compose down
docker compose up -d
```

### Проблема 2: База данных не создается

**Причина:** Недостаточно прав или mysql клиент не установлен

**Решение:**

```bash
# Используйте специальный скрипт для настройки БД
./scripts/setup-database.sh
```

Этот скрипт:
- Проверит подключение к MySQL
- Создаст пользователя если нужно
- Создаст базу данных
- Назначит права
- Проверит, что всё работает

**Ручное создание:**

```bash
# Подключитесь как root
sudo mysql -u root -p

# Создайте БД и пользователя
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

# Проверьте
SHOW DATABASES LIKE 'qemu%';
EXIT;

# Запустите миграции
docker compose exec app php artisan migrate --seed
```

**Подробная диагностика:** См. [DATABASE-TROUBLESHOOTING.RU.md](DATABASE-TROUBLESHOOTING.RU.md)

**Или используйте Docker БД:**

```bash
nano .env
# Измените DB_HOST=db

docker compose down
docker compose up -d
```

### Проблема 3: Ошибки bridge при запуске ВМ (bridge.conf, failed to drop privileges)

**Причина:** Не настроен bridge или ограничения Docker при bridge networking

**Решение 1 — bridge.conf:**
```bash
./scripts/fix-qemu-bridge.sh
docker compose down && docker compose up -d
```

**Решение 2 — "failed to drop privileges":** QEMU запускается на хосте через QemuControlService; в контейнере QEMU не используется. Убедитесь, что QemuControlService установлен и запущен на хосте.

**Альтернатива:** Переключите ВМ на тип сети "User (NAT)" в настройках ВМ — не требует bridge и работает в любом режиме Docker.

### Проблема 4: NPM ошибки на RISC-V

**Причина:** Node.js не установлен или неправильная версия

**Решение:**

```bash
# Войдите в контейнер
docker compose exec app bash

# Проверьте Node.js
node --version
npm --version

# Если не найден, пересоберите образ
exit
docker compose down
docker compose build --no-cache app
docker compose up -d

# Если снова ошибка, установите зависимости вручную
docker compose exec app npm install --legacy-peer-deps
```

### Проблема 5: Медленная сборка на RISC-V

**Причина:** Это нормально для RISC-V 😊

**Решение:**

```bash
# Наберитесь терпения ☕
# Сборка PHP образа: 15-25 минут
# NPM install: 5-10 минут
# NPM build: 2-4 минуты

# Следите за прогрессом
docker compose logs -f app
```

### Проблема 6: Apache2 не работает как proxy

**Причина:** Модули не включены или конфигурация неправильная

**Решение:**

```bash
# Включите модули
sudo a2enmod proxy
sudo a2enmod proxy_http

# Проверьте конфигурацию
sudo apache2ctl configtest

# Если ошибка, проверьте файл
sudo nano /etc/apache2/sites-available/qemu-control.conf

# Активируйте сайт
sudo a2ensite qemu-control.conf

# Перезапустите Apache2
sudo systemctl restart apache2

# Проверьте логи
sudo tail -f /var/log/apache2/error.log
```

### Проблема 7: "502 Bad Gateway" через Apache2

**Причина:** Docker контейнер не запущен или неправильный порт

**Решение:**

```bash
# Проверьте Docker
docker compose ps

# Проверьте, что приложение отвечает
curl http://localhost:8080

# Проверьте порт в Apache конфигурации
sudo nano /etc/apache2/sites-available/qemu-control.conf
# Убедитесь: ProxyPass / http://localhost:8080/

# Перезапустите Apache2
sudo systemctl restart apache2
```

### Проблема 8: Миграции не выполняются

**Причина:** База данных недоступна или неправильные учетные данные

**Решение:**

```bash
# Проверьте подключение
docker compose exec app php artisan db:show

# Если ошибка, проверьте .env
cat .env | grep DB_

# Проверьте, что БД доступна
docker compose exec app php artisan tinker
>>> DB::connection()->getPdo();

# Запустите миграции вручную
docker compose exec app php artisan migrate --force
docker compose exec app php artisan db:seed --force
```

### Проблема 9: Ошибка "SQLSTATE[HY000] [2002] Connection refused"

**Причина:** База данных не запущена или неправильный хост

**Решение:**

```bash
# Если используете Docker БД
docker compose ps db
# Если не запущена
docker compose up -d db

# Если используете внешнюю БД
sudo systemctl status mariadb
# Если не запущена
sudo systemctl start mariadb

# Проверьте DB_HOST в .env
cat .env | grep DB_HOST
# Для Docker БД должно быть: DB_HOST=db
# Для внешней БД: DB_HOST=localhost или IP
```

### Проблема 10: Превью 404 / «Нет сигнала»

**Причина:** QMP-сокет не найден; VM не запущена; или неверные права на `/var/qemu/qmp`

**Решение:**

```bash
# 1. Логи QemuControlService (на хосте)
sudo tail -f /var/log/QemuControlService.log

# 2. Права на /var/qemu/qmp (QEMU работает от root)
sudo chown root:root /var/qemu/qmp
sudo chmod 755 /var/qemu/qmp

# 3. VM должна быть запущена, проверьте сокет
ls -la /var/qemu/qmp/

# 4. Docker: QEMU_CONTROL_SERVICE_URL должен указывать на хост
sudo ./scripts/fix-boot-media-docker.sh
docker compose restart app
```

### Проблема 11: Белый экран или 500 ошибка

**Причина:** Ошибка в коде или неправильные права

**Решение:**

```bash
# Проверьте логи Laravel
docker compose exec app tail -f storage/logs/laravel.log

# Очистите кэш
docker compose exec app php artisan cache:clear
docker compose exec app php artisan config:clear
docker compose exec app php artisan view:clear

# Проверьте права
sudo chown -R 1000:1000 storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Пересоздайте ключ приложения
docker compose exec app php artisan key:generate --force
```

### Проблема 12: "Connection lost" при доступе к VNC с другого компьютера

**Причина:** WebSocket подключается, но websockify (на хосте) не может связаться с VNC QEMU, или firewall блокирует порт 50055.

**Решение:**

```bash
# 1. Проверьте, что ВМ запущена и VNC включён
docker compose exec app php artisan tinker
>>> \App\Models\VirtualMachine::find(1)->only(['status','vnc_port']);
# status должен быть running, vnc_port — 5900 или выше

# 2. Проверьте, что websockify слушает на хосте (порт 50055)
ss -tlnp | grep 50055
# QemuControlService запускает websockify при наличии VNC_TOKEN_FILE в qemu-control.conf

# 3. Проверьте VNC порт ВМ на хосте
ss -tlnp | grep 5900

# 4. Проверьте firewall (порты приложения и 50055)
sudo ufw status
sudo ufw allow 50055/tcp
sudo ufw reload

# 5. VNC_WS_HOST в .env — host:50055, доступный с клиентов
grep VNC_WS_HOST .env
# С хоста: VNC_WS_HOST=127.0.0.1:50055
# Из VM: VNC_WS_HOST=10.0.2.15:50055
# Из LAN: VNC_WS_HOST=192.168.1.41:50055

# 6. Перезапустите QemuControlService (перезапуск websockify)
sudo systemctl restart QemuControlService

# 7. Лог при открытии консоли (ws_url)
docker compose exec app tail -100 storage/logs/laravel.log | grep "VNC console opened"

# 8. Логи QemuControlService (включая websockify)
sudo tail -50 /var/log/QemuControlService.log
# Или: ./scripts/show_logs.sh qemu-control
```

**При доступе с RISC-V-клиента:** Убедитесь, что браузер поддерживает WebSocket. Попробуйте с другого устройства в той же сети — если там работает, возможна проблема браузера на RISC-V.

**При доступе с другого компьютера:** Задайте `VNC_WS_HOST` в `.env` — host:50055, доступный с клиента. Fallback: используется хост из запроса (APP_URL).

### Проблема 12a: "Connection lost" при доступе к VNC по HTTPS

**Причина:** При использовании HTTPS с самоподписанным сертификатом браузер может отклонять WebSocket-соединение, если сертификат не соответствует хосту (например, выдан для localhost, а доступ идёт по IP).

**Решение:**

1. **Примите сертификат до открытия консоли:** Откройте главную страницу приложения по HTTPS (например, `https://10.0.2.15:8080`), нажмите «Дополнительно» → «Перейти на сайт» (или аналогично в вашем браузере). Только после этого открывайте консоль ВМ.

2. **Сертификат для IP:** Если доступ по IP (10.0.2.15 и т.п.), создайте сертификат с SAN для этого IP:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout docker/nginx/ssl/server.key -out docker/nginx/ssl/server.crt \
     -subj "/CN=10.0.2.15" -addext "subjectAltName=IP:10.0.2.15"
   docker compose restart nginx
   ```

3. **Let's Encrypt:** При доступе по домену используйте сертификат Let's Encrypt (см. документацию по настройке).

### Проблема 13: Composer ошибки

**Причина:** Недостаточно памяти или проблемы с зависимостями

**Решение:**

```bash
# Увеличьте лимит памяти для Composer
docker compose exec app php -d memory_limit=-1 /usr/bin/composer install

# Или очистите кэш Composer
docker compose exec app composer clear-cache
docker compose exec app composer install --no-cache
```

### Проблема 14: QEMU сразу завершается — PipeWire "can't load config client.conf"

**Причина:** QEMU пытается использовать PipeWire для аудио на headless-сервере, где PipeWire не установлен или не настроен.

**Решение:**

По умолчанию аудио QEMU отключено (`QEMU_DISABLE_AUDIO=true` в конфиге). Если ошибка сохраняется:

```bash
# 1. Убедитесь, что аудио отключено (по умолчанию)
grep QEMU_DISABLE_AUDIO .env || echo "QEMU_DISABLE_AUDIO=true" >> .env

# 2. Пересоберите и перезапустите
docker compose down && docker compose up -d

# 3. Если ошибка сохраняется — установите PipeWire (альтернатива)
sudo apt install pipewire pipewire-pulse
# Или создайте минимальный конфиг: sudo mkdir -p /etc/pipewire && echo '{}' | sudo tee /etc/pipewire/client.conf
```

**Примечание:** QEMU 8.2+ использует `-audio none` для отключения аудио. На старых версиях установите PipeWire.

### Проблема 15: "Failed to get write lock" — образ диска занят

**Причина:** Другой процесс QEMU или зомби-процесс использует образ диска.

**Решение:**

```bash
# 1. Найдите процессы, использующие диск (проверьте QEMU_VM_STORAGE в .env)
VM_UUID="b47d58b5-232f-438e-87c1-7480c00a72c4"
DISK_PATH="/var/lib/qemu/vms/${VM_UUID}/disk.qcow2"

sudo lsof "$DISK_PATH"
# или
sudo fuser -v "$DISK_PATH"

# 2. Завершите зависшие процессы QEMU для этой ВМ
ps aux | grep qemu | grep "$VM_UUID"
sudo kill -9 <PID>

# 3. Если ВМ в статусе "running", но процесс мёртв — сбросьте статус в приложении
docker compose exec app php artisan tinker
>>> $vm = \App\Models\VirtualMachine::where('uuid', 'b47d58b5-232f-438e-87c1-7480c00a72c4')->first();
>>> $vm->update(['status' => 'stopped', 'pid' => null]);

# 4. Удалите stale lock (только если диск не используется)
sudo qemu-img check "$DISK_PATH"
# Если "No errors found", попробуйте запустить ВМ снова
```

## Диагностика

### Полная диагностика системы

```bash
#!/bin/bash
echo "=== System Info ==="
uname -a
echo ""

echo "=== Docker Version ==="
docker --version
docker compose version 2>/dev/null || docker-compose --version
echo ""

echo "=== Docker Status ==="
sudo systemctl status docker --no-pager
echo ""

echo "=== Containers Status ==="
docker compose ps
echo ""

echo "=== Container Logs (last 20 lines) ==="
docker compose logs --tail=20
echo ""

echo "=== Disk Space ==="
df -h
echo ""

echo "=== Memory Usage ==="
free -h
echo ""

echo "=== Network Ports ==="
sudo netstat -tlnp | grep -E ':(80|443|8080|8443|3306)'
echo ""

echo "=== Database Connection ==="
docker compose exec -T app php artisan db:show 2>&1 || echo "Database connection failed"
echo ""

echo "=== File Permissions ==="
ls -la storage/ | head -10
ls -la bootstrap/cache/ | head -10
echo ""

echo "=== Environment ==="
cat .env | grep -E '^(APP_|DB_)' | grep -v PASSWORD
echo ""
```

Запустите скрипт диагностики:

```bash
chmod +x scripts/diagnose.sh
./scripts/diagnose.sh > diagnosis.txt
cat diagnosis.txt
```

## Когда ничего не помогает

### Полная переустановка

```bash
# 1. Остановите и удалите все
./uninstall.sh --clean --lang ru

# 2. Очистите Docker
docker system prune -a --volumes
docker volume prune

# 3. Удалите базу данных (если внешняя)
sudo mysql -u root -p
DROP DATABASE IF EXISTS qemu_control;
EXIT;

# 4. Начните заново
./install.sh --lang ru
```

## Получение помощи

Если проблема не решается:

1. **Соберите диагностику:**
```bash
./scripts/diagnose.sh > diagnosis.txt
```

2. **Соберите логи:**
```bash
docker compose logs > docker-logs.txt
sudo tail -100 /var/log/apache2/error.log > apache-logs.txt
```

3. **Опишите проблему:**
   - Что вы пытались сделать
   - Что произошло
   - Сообщения об ошибках
   - Ваша система (Orange Pi RV2, Ubuntu, etc.)

4. **Приложите файлы:**
   - diagnosis.txt
   - docker-logs.txt
   - Скриншоты ошибок

## Известные ограничения

### На RISC-V (Orange Pi RV2):

- ⚠️ Сборка образов: 20-30 минут (терпение!)
- ⚠️ NPM может быть нестабильным (используйте `--legacy-peer-deps`)
- ⚠️ MariaDB может работать медленнее (рассмотрите внешнюю БД)
- ⚠️ Некоторые пакеты могут не иметь prebuilt бинарников

### Общие:

- ⚠️ VNC требует дополнительной настройки
- ⚠️ Эмуляция x86 ВМ на RISC-V медленная
- ⚠️ Первый запуск может занять 5-10 минут

## Советы для стабильной работы

1. **Используйте внешнюю БД** на RISC-V (быстрее и стабильнее)
2. **Увеличьте swap** если RAM < 4GB
3. **Регулярно очищайте** Docker кэш: `docker system prune`
4. **Мониторьте ресурсы**: `htop`, `docker stats`
5. **Делайте бэкапы** базы данных регулярно
6. **Проверяйте логи** при странном поведении
7. **Обновляйте систему**: `sudo apt update && sudo apt upgrade`

## Полезные ресурсы

- [Docker Documentation](https://docs.docker.com/)
- [Laravel Documentation](https://laravel.com/docs)
- [MariaDB Documentation](https://mariadb.org/documentation/)
- [Apache2 Documentation](https://httpd.apache.org/docs/)
- [QEMU Documentation](https://www.qemu.org/documentation/)

---

**Помните:** Установка на RISC-V - это приключение! Не все пойдет гладко с первого раза, и это нормально. 😊
