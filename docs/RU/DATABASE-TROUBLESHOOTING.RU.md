# Проблемы с базой данных - диагностика и решение

## Проблема: "Database created successfully" но БД не появилась

Это означает, что команда CREATE DATABASE выполнилась без ошибок, но база данных фактически не создалась.

### Диагностика

#### Шаг 1: Проверьте, что MySQL/MariaDB запущен

```bash
sudo systemctl status mariadb
# или
sudo systemctl status mysql
```

Если не запущен:
```bash
sudo systemctl start mariadb
sudo systemctl enable mariadb
```

#### Шаг 2: Проверьте подключение

```bash
# Подключитесь как root
sudo mysql -u root -p

# Или без пароля (на некоторых системах)
sudo mysql
```

#### Шаг 3: Проверьте список баз данных

В MySQL консоли:
```sql
SHOW DATABASES;
```

Ищите базу `qemu_control` или то имя, которое вы указали.

#### Шаг 4: Проверьте пользователя

```sql
SELECT User, Host FROM mysql.user WHERE User = 'qemu_user';
```

Если пользователя нет:
```sql
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;
```

### Автоматическое решение

Используйте скрипт `setup-database.sh`:

```bash
chmod +x scripts/setup-database.sh
./scripts/setup-database.sh
```

Скрипт:
1. Проверит подключение к MySQL
2. Проверит существование пользователя
3. Проверит существование базы данных
4. Создаст БД если её нет
5. Назначит права
6. Проверит доступ пользователя к БД
7. Покажет список всех БД

### Ручное решение

#### Вариант 1: Создание через root

```bash
# 1. Подключитесь как root
sudo mysql -u root -p

# 2. Создайте БД
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 3. Создайте пользователя (если нужно)
CREATE USER IF NOT EXISTS 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER IF NOT EXISTS 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';

# 4. Назначьте права
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

# 5. Проверьте
SHOW DATABASES;
USE qemu_control;
EXIT;

# 6. Проверьте доступ от пользователя
mysql -h localhost -u qemu_user -p qemu_control
# Введите пароль: qemu_password
SHOW TABLES;
EXIT;
```

#### Вариант 2: Использование Docker БД

Если не получается настроить внешнюю БД, используйте Docker:

```bash
# 1. Измените .env
nano .env
```

Установите:
```env
DB_HOST=db
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

```bash
# 2. Перезапустите контейнеры
docker compose down
docker compose up -d

# 3. Подождите 10 секунд
sleep 10

# 4. Запустите миграции
docker compose exec app php artisan migrate --seed
```

### Типичные причины проблемы

#### 1. Недостаточно прав у пользователя

**Симптом:** CREATE DATABASE выполняется, но БД не создается

**Причина:** У пользователя нет прав на создание БД

**Решение:**
```sql
-- Подключитесь как root
sudo mysql -u root -p

-- Дайте права на создание БД
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

#### 2. Пользователь не существует

**Симптом:** Подключение не работает

**Причина:** Пользователь не создан

**Решение:**
```sql
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;
```

#### 3. Неправильный пароль

**Симптом:** Access denied for user

**Причина:** Пароль в .env не совпадает с паролем в БД

**Решение:**
```sql
-- Измените пароль пользователя
ALTER USER 'qemu_user'@'localhost' IDENTIFIED BY 'new_password';
ALTER USER 'qemu_user'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

Обновите .env:
```env
DB_PASSWORD=new_password
```

#### 4. MySQL не слушает на нужном порту

**Симптом:** Connection refused

**Причина:** MySQL слушает только на localhost или другом порту

**Решение:**
```bash
# Проверьте конфигурацию
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Найдите и измените
bind-address = 0.0.0.0
# (или закомментируйте для Docker)

# Перезапустите
sudo systemctl restart mariadb
```

#### 5. Firewall блокирует порт

**Симптом:** Connection timeout

**Решение:**
```bash
# Откройте порт 3306
sudo ufw allow 3306/tcp

# Или для конкретного IP
sudo ufw allow from 172.17.0.0/16 to any port 3306
```

### Проверка через PhpMyAdmin

Если используете PhpMyAdmin:

1. **Обновите страницу** (F5)
2. **Проверьте фильтр** - возможно БД есть, но скрыта
3. **Проверьте права доступа** PhpMyAdmin пользователя
4. **Посмотрите в консоли MySQL** - PhpMyAdmin может кэшировать

### Финальная проверка

После всех манипуляций проверьте:

```bash
# 1. Подключитесь от пользователя приложения
mysql -h localhost -u qemu_user -p qemu_control

# 2. В MySQL консоли
SHOW TABLES;
SELECT DATABASE();
SHOW GRANTS FOR CURRENT_USER();
EXIT;

# 3. Проверьте из Laravel
docker compose exec app php artisan tinker
>>> DB::connection()->getDatabaseName();
>>> DB::table('migrations')->count();
>>> exit
```

### Если ничего не помогает

**Полная переустановка БД:**

```bash
# 1. Остановите приложение
./stop.sh

# 2. Удалите БД
sudo mysql -u root -p
DROP DATABASE IF EXISTS qemu_control;
DROP USER IF EXISTS 'qemu_user'@'localhost';
DROP USER IF EXISTS 'qemu_user'@'%';
FLUSH PRIVILEGES;
EXIT;

# 3. Создайте заново
sudo mysql -u root -p
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

-- Проверка
SHOW DATABASES LIKE 'qemu%';
USE qemu_control;
SHOW TABLES;
EXIT;

# 4. Проверьте подключение
mysql -h localhost -u qemu_user -p qemu_control

# 5. Обновите .env если нужно
nano .env

# 6. Запустите приложение
./start.sh --lang ru

# 7. Запустите миграции
docker compose exec app php artisan migrate:fresh --seed
```

## Полезные команды для диагностики

```bash
# Проверка статуса MySQL
sudo systemctl status mariadb

# Логи MySQL
sudo tail -f /var/log/mysql/error.log

# Список процессов MySQL
sudo ps aux | grep mysql

# Проверка портов
sudo netstat -tlnp | grep 3306

# Проверка из Laravel
docker compose exec app php artisan db:show

# Список всех пользователей MySQL
sudo mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# Список прав пользователя
sudo mysql -u root -p -e "SHOW GRANTS FOR 'qemu_user'@'localhost';"
```

## Скрипты для помощи

```bash
# Автоматическая настройка БД
./scripts/setup-database.sh

# Диагностика системы
./scripts/diagnose.sh

# Проверка подключения вручную
mysql -h localhost -u qemu_user -p
```

## Важные замечания

1. **PhpMyAdmin кэширует список БД** - обновите страницу
2. **Проверяйте в консоли MySQL** - это источник истины
3. **CREATE DATABASE IF NOT EXISTS** может вернуть успех даже если БД уже есть
4. **GRANT может молчать** если привилегии уже назначены
5. **На RISC-V** MariaDB может работать медленнее - дайте время

## Если скрипт врет

Если `install.sh` говорит "Database created successfully", но БД нет:

1. **Не доверяйте скрипту слепо** 😊
2. **Проверьте вручную** в MySQL консоли
3. **Используйте** `./scripts/setup-database.sh` для повторной попытки
4. **Смотрите логи** MySQL в `/var/log/mysql/error.log`

---

**Помните:** Автоматизация не всегда идеальна, особенно с БД! Ручная проверка - ваш друг. 👍

---

**Языковые версии:** [DATABASE-TROUBLESHOOTING.EN.md](../EN/DATABASE-TROUBLESHOOTING.EN.md) | [DATABASE-TROUBLESHOOTING.RU.md](DATABASE-TROUBLESHOOTING.RU.md)
