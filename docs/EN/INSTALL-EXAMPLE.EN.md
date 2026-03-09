# Interactive Installation Example

## Scenario 1: Installation with Docker DB (default)

```bash
./install.sh --lang ru
```

```
╔══════════════════════════════════════════════════════════════════════════╗
║                   QEMU Web Control Installer                            ║
╠══════════════════════════════════════════════════════════════════════════╣

➜ Checking Docker installation...
✓ Docker installed

➜ Checking Apache2 installation...
✓ Apache2 installed
Configure Apache2 as reverse proxy? [y/n]: n

➜ Checking environment configuration...
➜ Creating .env from .env.example...
✓ Environment file created

Select database configuration:
  [1] Docker MariaDB (isolated)
  [2] External MariaDB/MySQL (existing)
Enter your choice [1-2]: [1]: ⏎ (just Enter)
➜ Using Docker MariaDB (isolated)

➜ Generating SSL certificates...
✓ SSL certificates generated

➜ Fixing permissions...
✓ Permissions fixed

➜ Building Docker containers...
[+] Building 1234.5s
✓ Containers built

➜ Starting containers...
✓ Containers started

...
```

## Scenario 2: Installation with external DB

```bash
./install.sh --lang ru
```

```
...

Select database configuration:
  [1] Docker MariaDB (isolated)
  [2] External MariaDB/MySQL (existing)
Enter your choice [1-2]: [1]: 2

Enter database host [localhost]: ⏎
Enter database port [3306]: ⏎
Enter database name [qemu_control]: ⏎
Enter database username [qemu_user]: ⏎
Enter database password: mypassword123

➜ Checking database connection...
✓ Database connection successful
➜ Creating database...
✓ Database created successfully
➜ Assigning privileges...
✓ Privileges assigned successfully

...
```

## Scenario 3: Installation with Apache2 proxy

```bash
./install.sh --lang ru
```

```
...

➜ Checking Apache2 installation...
✓ Apache2 installed
Configure Apache2 as reverse proxy? [y/n]: y
Enter Apache2 proxy port (default 80): [80]: ⏎

➜ Configuring Apache2 reverse proxy...
➜ Enabling Apache2 modules...
➜ Restarting Apache2...
✓ Apache2 configured successfully

...
```

## Scenario 4: Installation with custom DB parameters

```bash
./install.sh --lang ru
```

```
...

Select database configuration:
  [1] Docker MariaDB (isolated)
  [2] External MariaDB/MySQL (existing)
Enter your choice [1-2]: [1]: 2

Enter database host [localhost]: 192.168.1.100
Enter database port [3306]: 3307
Enter database name [qemu_control]: my_qemu_db
Enter database username [qemu_user]: my_user
Enter database password: my_secure_password

➜ Checking database connection...
✓ Database connection successful
✓ Database already exists
➜ Assigning privileges...
✓ Privileges assigned successfully

...
```

## Scenario 5: Reinstallation (values from .env)

If you run installation again, the script will offer current values from `.env`:

```bash
./install.sh --lang ru
```

```
...

Select database configuration:
  [1] Docker MariaDB (isolated)
  [2] External MariaDB/MySQL (existing)
Enter your choice [1-2]: [1]: 2

Enter database host [192.168.1.100]: ⏎  (uses 192.168.1.100)
Enter database port [3307]: ⏎  (uses 3307)
Enter database name [my_qemu_db]: ⏎  (uses my_qemu_db)
Enter database username [my_user]: ⏎  (uses my_user)
Enter database password: (must enter again)

...
```

## Scenario 6: Error - empty password

```bash
./install.sh --lang ru
```

```
...

Enter database password: ⏎  (empty input)

⚠ Password cannot be empty!
Enter database password: mypassword123

...
```

## Scenario 7: DB not created - root password requested

```bash
./install.sh --lang ru
```

```
...

Enter database password: userpassword

➜ Checking database connection...
✓ Database connection successful
➜ Creating database...
⚠ Cannot create database with user credentials
Enter database root password: rootpassword

✓ Database created successfully
➜ Assigning privileges...
✓ Privileges assigned successfully

...
```

## Useful tips

### Using default values

For quick installation with default settings just press Enter:

```bash
./install.sh --lang ru

# DB choice: Enter (Docker MariaDB)
# Apache2: n Enter (don't configure)
# Done!
```

### Changing only one parameter

If you need to change only one parameter (e.g. database name):

```bash
Enter database host [localhost]: ⏎
Enter database port [3306]: ⏎
Enter database name [qemu_control]: my_custom_db  ← changed
Enter database username [qemu_user]: ⏎
```

### Automatic installation (non-interactive)

For automatic installation you can pre-configure `.env`:

```bash
# 1. Copy and configure .env
cp .env.example .env
nano .env

# 2. Set required values
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=qemu_control
DB_USERNAME=qemu_user
DB_PASSWORD=mypassword

# 3. Run installation
# Script uses values from .env as defaults
./install.sh --lang ru
```

## Notes

- **[value]** - default value, used when pressing Enter
- **⏎** - Enter key press (use default value)
- **✓** - success
- **✗** - error
- **⚠** - warning
- **➜** - in progress

## What to do if...

### Input error

If you entered wrong value:
1. Wait for installation to complete
2. Edit `.env`
3. Restart containers: `./restart.sh`

### Want to change settings after installation

```bash
# 1. Stop containers
./stop.sh

# 2. Edit .env
nano .env

# 3. If DB changed, run migrations
docker compose exec app php artisan migrate:fresh --seed

# 4. Start containers
./start.sh
```

### Forgot DB password

If you forgot the password you entered:

```bash
# Check in .env
cat .env | grep DB_PASSWORD
```

**Important:** `.env` contains passwords in plain text, be careful!

---

**Language versions:** [INSTALL-EXAMPLE.EN.md](INSTALL-EXAMPLE.EN.md) | [INSTALL-EXAMPLE.RU.md](../RU/INSTALL-EXAMPLE.RU.md)
