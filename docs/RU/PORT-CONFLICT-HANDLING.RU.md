# Автоматическая обработка конфликтов портов

## Описание

Проект автоматически обнаруживает и исправляет конфликты портов во время установки и запуска.

## Как это работает

### 1. При установке (`install.sh`)

```bash
./install.sh --lang ru
```

**Автоматические действия:**

1. **Проверка портов перед запуском**
   - Проверяет доступность портов из `.env` (по умолчанию 8080, 8443)
   - Если порты заняты, предлагает свободные альтернативы

2. **Интерактивное исправление**
   ```
   ⚠ Port 8080 is already in use
   
   ➜ Suggested free ports:
     HTTP:  8081
     HTTPS: 8444
   
   Use these ports? [Y/n]:
   ```

3. **Автоматическое обновление конфигурации**
   - Обновляет `.env` с новыми портами
   - Продолжает установку с исправленными портами

4. **Повторная попытка при ошибке**
   - Если порт занялся во время запуска контейнеров
   - Автоматически находит новые свободные порты
   - Перезапускает контейнеры

### 2. При запуске (`start.sh`)

```bash
./start.sh --lang ru
```

**Автоматические действия:**

1. **Попытка запуска**
   - Пытается запустить контейнеры с текущими портами

2. **Обнаружение конфликта**
   ```
   ⚠ Port conflict detected
   ➜ Attempting to fix port conflict...
   ```

3. **Автоматическое исправление**
   - Находит свободные порты (начиная с 8081, 8444)
   - Обновляет `.env`
   - Перезапускает контейнеры

4. **Успешный запуск**
   ```
   ✓ Ports updated: HTTP=8081, HTTPS=8444
   ➜ Retrying with new ports...
   ✓ Application started successfully
   
   ➜ Application is available at:
   ✓   HTTP:  http://localhost:8081
   ✓   HTTPS: https://localhost:8081
   ```

### 3. При перезапуске (`restart.sh`)

Работает аналогично `start.sh` - автоматически исправляет конфликты портов.

### 4. Ручное исправление (`fix-port-conflict.sh`)

Если автоматическое исправление не сработало:

```bash
./scripts/fix-port-conflict.sh
```

**Опции:**
1. Изменить порты приложения (рекомендуется)
2. Остановить процесс, использующий порт
3. Автоматически найти свободные порты

## Алгоритм поиска свободных портов

```bash
# Начинаем с порта 8081 для HTTP
port=8081
while port_is_busy($port) && port < 9000; do
    port = port + 1
done

# Начинаем с порта 8444 для HTTPS
ssl_port=8444
while port_is_busy($ssl_port) && ssl_port < 9000; do
    ssl_port = ssl_port + 1
done
```

**Диапазон поиска:** 8081-8999 для HTTP, 8444-8999 для HTTPS

## Проверка занятости порта

Используются команды:
```bash
ss -tlnp | grep ":$port "      # Предпочтительно
netstat -tlnp | grep ":$port " # Fallback
```

## Примеры использования

### Пример 1: Установка с занятым портом 8080

```bash
./install.sh --lang ru

# Вывод:
⚠ Port 8080 is already in use

➜ Suggested free ports:
  HTTP:  8081
  HTTPS: 8444

Use these ports? [Y/n]: y

✓ Ports updated: HTTP=8081, HTTPS=8444
➜ Starting containers...
✓ Application started successfully
```

### Пример 2: Запуск с конфликтом портов

```bash
./start.sh --lang ru

# Вывод:
➜ Starting QEMU Web Control...
⚠ Port conflict detected
➜ Attempting to fix port conflict...
✓ Ports updated: HTTP=8082, HTTPS=8445
➜ Retrying with new ports...
✓ Application started successfully

➜ Application is available at:
✓   HTTP:  http://localhost:8082
✓   HTTPS: https://localhost:8445
```

### Пример 3: Ручное исправление

```bash
./scripts/fix-port-conflict.sh

# Интерактивное меню:
╔══════════════════════════════════════════════════════════════════════════╗
║                    Fix Port Conflict - QEMU Web Control                 ║
╚══════════════════════════════════════════════════════════════════════════╝

➜ Current ports:
  HTTP:  8080
  HTTPS: 8443

➜ Checking which ports are in use...

✗ Port 8080 is already in use

Process using port 8080:
  nginx   1234/nginx

⚠ Port conflict detected!

Solutions:

1) Change application ports (recommended)
2) Stop the process using the port
3) Find free ports automatically

Select option [1-3]: 1
```

## Логирование

Все операции с портами логируются во временные файлы:
- `/tmp/docker_up.log` - вывод `docker compose up`
- `/tmp/start_output.log` - вывод при запуске через `start.sh`

Файлы автоматически удаляются после успешного запуска.

## Конфигурация

### Изменение диапазона портов

По умолчанию поиск ведется в диапазоне 8081-8999. Для изменения отредактируйте функции в скриптах:

```bash
# В install.sh, start.sh, restart.sh
find_free_port() {
    local start_port=$1
    local port=$start_port
    
    # Изменить 9000 на нужное значение
    while check_port $port && [ $port -lt 9000 ]; do
        port=$((port + 1))
    done
    
    echo $port
}
```

### Отключение автоматического исправления

Если нужно отключить автоматическое исправление портов, закомментируйте вызов функции:

```bash
# В install.sh
# check_and_fix_ports  # Отключено

# В start.sh
# Удалить проверку на "address already in use"
```

## Диагностика

### Проверить какие порты заняты

```bash
# Все занятые порты
ss -tlnp

# Конкретный порт
ss -tlnp | grep :8080

# Или через netstat
netstat -tlnp | grep :8080
```

### Проверить текущие порты приложения

```bash
grep -E "APP_PORT|APP_SSL_PORT" .env
```

### Проверить порты контейнеров

```bash
docker compose ps
# или
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

## Известные ограничения

1. **Диапазон портов:** Поиск ограничен портами до 9000
2. **Привилегированные порты:** Порты < 1024 требуют root прав
3. **Firewall:** Убедитесь, что новые порты открыты в firewall
4. **Одновременный запуск:** Если два процесса одновременно ищут порты, возможен конфликт

## Рекомендации

1. **Используйте стандартные порты** (8080, 8443) если они свободны
2. **Проверяйте порты перед установкой:** `ss -tlnp | grep -E ':(8080|8443)'`
3. **Документируйте изменения:** Если меняете порты, обновите документацию
4. **Используйте Apache/Nginx proxy:** Для стандартных портов 80/443

## Интеграция с другими компонентами

### Apache2 Reverse Proxy

Если используется Apache2 как reverse proxy, порты приложения не важны:

```apache
ProxyPass / http://localhost:8081/
ProxyPassReverse / http://localhost:8081/
```

Пользователи будут обращаться к стандартным портам 80/443.

### Firewall

После изменения портов обновите правила firewall:

```bash
sudo ufw allow 8081/tcp
sudo ufw allow 8444/tcp
```

### Systemd Service

Если используется systemd для автозапуска, порты берутся из `.env` автоматически.

## Поддержка

Если автоматическое исправление не работает:

1. Запустите диагностику: `./scripts/full-diagnostic.sh`
2. Проверьте логи: `docker compose logs`
3. Используйте ручное исправление: `./scripts/fix-port-conflict.sh`
4. См. [TROUBLESHOOTING.EN.md](../EN/TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](TROUBLESHOOTING.RU.md)

---

**Языковые версии:** [PORT-CONFLICT-HANDLING.EN.md](../EN/PORT-CONFLICT-HANDLING.EN.md) | [PORT-CONFLICT-HANDLING.RU.md](PORT-CONFLICT-HANDLING.RU.md)
