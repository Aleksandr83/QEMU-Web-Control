# Automatic Port Conflict Handling

## Description

The project automatically detects and resolves port conflicts during installation and startup.

## How It Works

### 1. During Installation (`install.sh`)

```bash
./install.sh --lang ru
```

**Automatic actions:**

1. **Port check before startup**
   - Checks availability of ports from `.env` (default 8080, 8443)
   - If ports are in use, suggests free alternatives

2. **Interactive fix**
   ```
   ⚠ Port 8080 is already in use
   
   ➜ Suggested free ports:
     HTTP:  8081
     HTTPS: 8444
   
   Use these ports? [Y/n]:
   ```

3. **Automatic configuration update**
   - Updates `.env` with new ports
   - Continues installation with fixed ports

4. **Retry on error**
   - If a port becomes occupied during container startup
   - Automatically finds new free ports
   - Restarts containers

### 2. During Startup (`start.sh`)

```bash
./start.sh --lang ru
```

**Automatic actions:**

1. **Startup attempt**
   - Tries to start containers with current ports

2. **Conflict detection**
   ```
   ⚠ Port conflict detected
   ➜ Attempting to fix port conflict...
   ```

3. **Automatic fix**
   - Finds free ports (starting from 8081, 8444)
   - Updates `.env`
   - Restarts containers

4. **Successful startup**
   ```
   ✓ Ports updated: HTTP=8081, HTTPS=8444
   ➜ Retrying with new ports...
   ✓ Application started successfully
   
   ➜ Application is available at:
   ✓   HTTP:  http://localhost:8081
   ✓   HTTPS: https://localhost:8081
   ```

### 3. During Restart (`restart.sh`)

Works the same as `start.sh` - automatically fixes port conflicts.

### 4. Manual Fix (`fix-port-conflict.sh`)

If automatic fix does not work:

```bash
./scripts/fix-port-conflict.sh
```

**Options:**
1. Change application ports (recommended)
2. Stop the process using the port
3. Automatically find free ports

## Free Port Search Algorithm

```bash
# Start with port 8081 for HTTP
port=8081
while port_is_busy($port) && port < 9000; do
    port = port + 1
done

# Start with port 8444 for HTTPS
ssl_port=8444
while port_is_busy($ssl_port) && ssl_port < 9000; do
    ssl_port = ssl_port + 1
done
```

**Search range:** 8081-8999 for HTTP, 8444-8999 for HTTPS

## Port Availability Check

Uses commands:
```bash
ss -tlnp | grep ":$port "      # Preferred
netstat -tlnp | grep ":$port " # Fallback
```

## Usage Examples

### Example 1: Installation with port 8080 in use

```bash
./install.sh --lang ru

# Output:
⚠ Port 8080 is already in use

➜ Suggested free ports:
  HTTP:  8081
  HTTPS: 8444

Use these ports? [Y/n]: y

✓ Ports updated: HTTP=8081, HTTPS=8444
➜ Starting containers...
✓ Application started successfully
```

### Example 2: Startup with port conflict

```bash
./start.sh --lang ru

# Output:
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

### Example 3: Manual fix

```bash
./scripts/fix-port-conflict.sh

# Interactive menu:
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

## Logging

All port operations are logged to temporary files:
- `/tmp/docker_up.log` - output of `docker compose up`
- `/tmp/start_output.log` - output when starting via `start.sh`

Files are automatically removed after successful startup.

## Configuration

### Changing port range

By default, search is in range 8081-8999. To change, edit functions in scripts:

```bash
# In install.sh, start.sh, restart.sh
find_free_port() {
    local start_port=$1
    local port=$start_port
    
    # Change 9000 to desired value
    while check_port $port && [ $port -lt 9000 ]; do
        port=$((port + 1))
    done
    
    echo $port
}
```

### Disabling automatic fix

To disable automatic port fix, comment out the function call:

```bash
# In install.sh
# check_and_fix_ports  # Disabled

# In start.sh
# Remove check for "address already in use"
```

## Diagnostics

### Check which ports are in use

```bash
# All used ports
ss -tlnp

# Specific port
ss -tlnp | grep :8080

# Or via netstat
netstat -tlnp | grep :8080
```

### Check current application ports

```bash
grep -E "APP_PORT|APP_SSL_PORT" .env
```

### Check container ports

```bash
docker compose ps
# or
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

## Known Limitations

1. **Port range:** Search limited to ports up to 9000
2. **Privileged ports:** Ports < 1024 require root
3. **Firewall:** Ensure new ports are open in firewall
4. **Concurrent startup:** If two processes search for ports simultaneously, conflict is possible

## Recommendations

1. **Use standard ports** (8080, 8443) if they are free
2. **Check ports before installation:** `ss -tlnp | grep -E ':(8080|8443)'`
3. **Document changes:** If you change ports, update documentation
4. **Use Apache/Nginx proxy:** For standard ports 80/443

## Integration with Other Components

### Apache2 Reverse Proxy

If Apache2 is used as reverse proxy, application ports do not matter:

```apache
ProxyPass / http://localhost:8081/
ProxyPassReverse / http://localhost:8081/
```

Users will access standard ports 80/443.

### Firewall

After changing ports, update firewall rules:

```bash
sudo ufw allow 8081/tcp
sudo ufw allow 8444/tcp
```

### Systemd Service

If systemd is used for autostart, ports are taken from `.env` automatically.

## Support

If automatic fix does not work:

1. Run diagnostics: `./scripts/full-diagnostic.sh`
2. Check logs: `docker compose logs`
3. Use manual fix: `./scripts/fix-port-conflict.sh`
4. See [TROUBLESHOOTING.EN.md](TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](../RU/TROUBLESHOOTING.RU.md)

---

**Language versions:** [PORT-CONFLICT-HANDLING.EN.md](PORT-CONFLICT-HANDLING.EN.md) | [PORT-CONFLICT-HANDLING.RU.md](../RU/PORT-CONFLICT-HANDLING.RU.md)
