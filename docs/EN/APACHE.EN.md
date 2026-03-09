# Apache2 Reverse Proxy Setup

## Automatic setup

The `install.sh` script automatically detects Apache2 and offers to configure it as a reverse proxy.

```bash
./install.sh --lang ru
```

When Apache2 is detected you will see:
```
✓ Apache2 installed
Configure Apache2 as reverse proxy? [y/n]:
```

If you answer `y`, the script will:
1. Create virtual host configuration
2. Enable required modules (proxy, proxy_http)
3. Activate the site
4. Restart Apache2

## Manual setup

### Step 1: Enable modules

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers
```

### Step 2: Create configuration

Create file `/etc/apache2/sites-available/qemu-control.conf`:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    # Or ServerName localhost for local access
    
    # Reverse proxy to Docker container
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
    
    # Headers for correct operation
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
    
    # Logs
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-access.log combined
</VirtualHost>
```

### Step 3: For HTTPS (optional)

Create HTTPS configuration:

```apache
<VirtualHost *:443>
    ServerName your-domain.com
    
    # SSL certificates
    SSLEngine on
    SSLCertificateFile /path/to/your/certificate.crt
    SSLCertificateKeyFile /path/to/your/private.key
    
    # Reverse proxy to Docker container (HTTPS)
    ProxyPreserveHost On
    ProxyPass / https://localhost:8443/
    ProxyPassReverse / https://localhost:8443/
    
    # SSL Proxy
    SSLProxyEngine On
    SSLProxyVerify none
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerName off
    
    # Headers
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    
    # Logs
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-ssl-access.log combined
</VirtualHost>
```

Enable SSL module:
```bash
sudo a2enmod ssl
```

### Step 4: Activate site

```bash
# Activate configuration
sudo a2ensite qemu-control.conf

# Verify configuration
sudo apache2ctl configtest

# Restart Apache2
sudo systemctl restart apache2
```

### Step 5: Disable default site (optional)

```bash
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

## Configuration with domain name

If you have a domain name:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    ServerAlias www.qemu.example.com
    
    # Redirect to HTTPS
    Redirect permanent / https://qemu.example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName qemu.example.com
    ServerAlias www.qemu.example.com
    
    # SSL certificates (Let's Encrypt)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/qemu.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/qemu.example.com/privkey.pem
    
    # Reverse proxy
    ProxyPreserveHost On
    ProxyPass / https://localhost:8443/
    ProxyPassReverse / https://localhost:8443/
    
    # SSL Proxy
    SSLProxyEngine On
    SSLProxyVerify none
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerName off
    
    # Headers
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    RequestHeader set X-Forwarded-Host "qemu.example.com"
    
    # Logs
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-access.log combined
</VirtualHost>
```

## Let's Encrypt SSL

### Certbot installation

```bash
sudo apt-get install -y certbot python3-certbot-apache
```

### Obtaining certificate

```bash
sudo certbot --apache -d qemu.example.com -d www.qemu.example.com
```

Certbot will automatically:
- Obtain certificate
- Configure Apache2
- Set up auto-renewal

### Verify auto-renewal

```bash
sudo certbot renew --dry-run
```

## Laravel configuration for proxy

If the application runs behind Apache2 proxy, update `.env`:

```env
APP_URL=https://qemu.example.com
```

And add to `bootstrap/app.php` (if needed):

```php
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->trustProxies(at: '*');
    })
    // ...
```

## Security

### IP access restriction

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Allow access only from specific IPs
    <Location />
        Require ip 192.168.1.0/24
        Require ip 10.0.0.0/8
    </Location>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

### Basic authentication

```bash
# Create password file
sudo htpasswd -c /etc/apache2/.htpasswd admin
```

Add to configuration:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    <Location />
        AuthType Basic
        AuthName "QEMU Control Access"
        AuthUserFile /etc/apache2/.htpasswd
        Require valid-user
    </Location>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

### DDoS protection

Install mod_evasive:

```bash
sudo apt-get install libapache2-mod-evasive
sudo a2enmod evasive
```

Configure `/etc/apache2/mods-available/evasive.conf`:

```apache
<IfModule mod_evasive20.c>
    DOSHashTableSize 3097
    DOSPageCount 5
    DOSSiteCount 100
    DOSPageInterval 1
    DOSSiteInterval 1
    DOSBlockingPeriod 60
</IfModule>
```

## Monitoring

### Apache2 logs

```bash
# Error logs
sudo tail -f /var/log/apache2/qemu-control-error.log

# Access logs
sudo tail -f /var/log/apache2/qemu-control-access.log

# All Apache2 logs
sudo tail -f /var/log/apache2/*.log
```

### Apache2 status

```bash
# Service status
sudo systemctl status apache2

# Configuration check
sudo apache2ctl configtest

# List active sites
sudo apache2ctl -S
```

## Performance

### Caching

Enable mod_cache:

```bash
sudo a2enmod cache
sudo a2enmod cache_disk
```

Add to configuration:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Static content caching
    <Location /build>
        CacheEnable disk
        CacheHeader on
        CacheDefaultExpire 3600
        CacheMaxExpire 86400
    </Location>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

### Compression

Enable mod_deflate:

```bash
sudo a2enmod deflate
```

Add to configuration:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
    </IfModule>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

## Troubleshooting

### 502 Bad Gateway error

Check:
1. Is Docker container running:
```bash
docker compose ps
```

2. Is port 8080 accessible:
```bash
curl http://localhost:8080
```

3. Apache2 logs:
```bash
sudo tail -f /var/log/apache2/qemu-control-error.log
```

### 503 Service Unavailable error

Check:
1. Port correctness in configuration
2. Firewall is not blocking ports
3. SELinux allows proxy (on CentOS/RHEL)

### Slow performance

1. Enable caching (see above)
2. Increase timeouts:

```apache
ProxyTimeout 300
```

3. Optimize Apache2:

```apache
# /etc/apache2/mods-available/mpm_prefork.conf
<IfModule mpm_prefork_module>
    StartServers 5
    MinSpareServers 5
    MaxSpareServers 10
    MaxRequestWorkers 150
    MaxConnectionsPerChild 0
</IfModule>
```

## Removing configuration

```bash
# Disable site
sudo a2dissite qemu-control.conf

# Remove configuration
sudo rm /etc/apache2/sites-available/qemu-control.conf

# Restart Apache2
sudo systemctl reload apache2
```

## Useful commands

```bash
# Restart Apache2
sudo systemctl restart apache2

# Reload configuration without stopping
sudo systemctl reload apache2

# Syntax check
sudo apache2ctl configtest

# List modules
sudo apache2ctl -M

# Enable module
sudo a2enmod module_name

# Disable module
sudo a2dismod module_name

# List sites
sudo apache2ctl -S
```

## Additional information

- [Apache2 Proxy Guide](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Laravel Behind Proxy](https://laravel.com/docs/11.x/requests#configuring-trusted-proxies)

---

**Language versions:** [APACHE.EN.md](APACHE.EN.md) | [APACHE.RU.md](../RU/APACHE.RU.md)
