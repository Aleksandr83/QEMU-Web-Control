# Database Issues - Diagnostics and Solutions

## Problem: "Database created successfully" but DB did not appear

This means the CREATE DATABASE command completed without errors, but the database was not actually created.

### Diagnostics

#### Step 1: Check that MySQL/MariaDB is running

```bash
sudo systemctl status mariadb
# or
sudo systemctl status mysql
```

If not running:
```bash
sudo systemctl start mariadb
sudo systemctl enable mariadb
```

#### Step 2: Check connection

```bash
# Connect as root
sudo mysql -u root -p

# Or without password (on some systems)
sudo mysql
```

#### Step 3: Check database list

In MySQL console:
```sql
SHOW DATABASES;
```

Look for database `qemu_control` or the name you specified.

#### Step 4: Check user

```sql
SELECT User, Host FROM mysql.user WHERE User = 'qemu_user';
```

If user does not exist:
```sql
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;
```

### Automatic solution

Use `setup-database.sh` script:

```bash
chmod +x scripts/setup-database.sh
./scripts/setup-database.sh
```

The script will:
1. Check MySQL connection
2. Check user existence
3. Check database existence
4. Create DB if missing
5. Assign privileges
6. Verify user access to DB
7. Show list of all databases

### Manual solution

#### Option 1: Create via root

```bash
# 1. Connect as root
sudo mysql -u root -p

# 2. Create database
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 3. Create user (if needed)
CREATE USER IF NOT EXISTS 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER IF NOT EXISTS 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';

# 4. Grant privileges
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

# 5. Verify
SHOW DATABASES;
USE qemu_control;
EXIT;

# 6. Verify user access
mysql -h localhost -u qemu_user -p qemu_control
# Enter password: qemu_password
SHOW TABLES;
EXIT;
```

#### Option 2: Use Docker DB

If external DB setup fails, use Docker:

```bash
# 1. Edit .env
nano .env
```

Set:
```env
DB_HOST=db
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=qemu_password
```

```bash
# 2. Restart containers
docker compose down
docker compose up -d

# 3. Wait 10 seconds
sleep 10

# 4. Run migrations
docker compose exec app php artisan migrate --seed
```

### Common causes

#### 1. Insufficient user privileges

**Symptom:** CREATE DATABASE runs but DB is not created

**Cause:** User lacks privileges to create databases

**Solution:**
```sql
-- Connect as root
sudo mysql -u root -p

-- Grant DB creation privileges
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'qemu_user'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

#### 2. User does not exist

**Symptom:** Connection fails

**Cause:** User not created

**Solution:**
```sql
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;
```

#### 3. Wrong password

**Symptom:** Access denied for user

**Cause:** Password in .env does not match DB password

**Solution:**
```sql
-- Change user password
ALTER USER 'qemu_user'@'localhost' IDENTIFIED BY 'new_password';
ALTER USER 'qemu_user'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

Update .env:
```env
DB_PASSWORD=new_password
```

#### 4. MySQL not listening on required port

**Symptom:** Connection refused

**Cause:** MySQL listens only on localhost or different port

**Solution:**
```bash
# Check configuration
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Find and change
bind-address = 0.0.0.0
# (or comment out for Docker)

# Restart
sudo systemctl restart mariadb
```

#### 5. Firewall blocking port

**Symptom:** Connection timeout

**Solution:**
```bash
# Open port 3306
sudo ufw allow 3306/tcp

# Or for specific IP
sudo ufw allow from 172.17.0.0/16 to any port 3306
```

### PhpMyAdmin check

If using PhpMyAdmin:

1. **Refresh page** (F5)
2. **Check filter** - DB may exist but be hidden
3. **Check PhpMyAdmin user privileges**
4. **Check MySQL console** - PhpMyAdmin may cache

### Final verification

After all steps, verify:

```bash
# 1. Connect as application user
mysql -h localhost -u qemu_user -p qemu_control

# 2. In MySQL console
SHOW TABLES;
SELECT DATABASE();
SHOW GRANTS FOR CURRENT_USER();
EXIT;

# 3. Check from Laravel
docker compose exec app php artisan tinker
>>> DB::connection()->getDatabaseName();
>>> DB::table('migrations')->count();
>>> exit
```

### If nothing helps

**Full DB reinstall:**

```bash
# 1. Stop application
./stop.sh

# 2. Drop database
sudo mysql -u root -p
DROP DATABASE IF EXISTS qemu_control;
DROP USER IF EXISTS 'qemu_user'@'localhost';
DROP USER IF EXISTS 'qemu_user'@'%';
FLUSH PRIVILEGES;
EXIT;

# 3. Create from scratch
sudo mysql -u root -p
CREATE DATABASE qemu_control CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'qemu_user'@'localhost' IDENTIFIED BY 'qemu_password';
CREATE USER 'qemu_user'@'%' IDENTIFIED BY 'qemu_password';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'localhost';
GRANT ALL PRIVILEGES ON qemu_control.* TO 'qemu_user'@'%';
FLUSH PRIVILEGES;

-- Verify
SHOW DATABASES LIKE 'qemu%';
USE qemu_control;
SHOW TABLES;
EXIT;

# 4. Verify connection
mysql -h localhost -u qemu_user -p qemu_control

# 5. Update .env if needed
nano .env

# 6. Start application
./start.sh --lang ru

# 7. Run migrations
docker compose exec app php artisan migrate:fresh --seed
```

## Useful diagnostic commands

```bash
# MySQL status
sudo systemctl status mariadb

# MySQL logs
sudo tail -f /var/log/mysql/error.log

# MySQL processes
sudo ps aux | grep mysql

# Port check
sudo netstat -tlnp | grep 3306

# Laravel check
docker compose exec app php artisan db:show

# List all MySQL users
sudo mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# User privileges
sudo mysql -u root -p -e "SHOW GRANTS FOR 'qemu_user'@'localhost';"
```

## Helper scripts

```bash
# Automatic DB setup
./scripts/setup-database.sh

# System diagnostics
./scripts/diagnose.sh

# Manual connection check
mysql -h localhost -u qemu_user -p
```

## Important notes

1. **PhpMyAdmin caches DB list** - refresh the page
2. **Check in MySQL console** - it is the source of truth
3. **CREATE DATABASE IF NOT EXISTS** may return success even if DB already exists
4. **GRANT may be silent** if privileges are already assigned
5. **On RISC-V** MariaDB may be slower - give it time

## If the script lies

If `install.sh` says "Database created successfully" but DB is missing:

1. **Don't trust the script blindly** 😊
2. **Verify manually** in MySQL console
3. **Use** `./scripts/setup-database.sh` for another attempt
4. **Check logs** in `/var/log/mysql/error.log`

---

**Remember:** Automation is not always perfect, especially with databases! Manual verification is your friend. 👍

---

**Language versions:** [DATABASE-TROUBLESHOOTING.EN.md](DATABASE-TROUBLESHOOTING.EN.md) | [DATABASE-TROUBLESHOOTING.RU.md](../RU/DATABASE-TROUBLESHOOTING.RU.md)
