# Настройка Apache2 как Reverse Proxy

## Автоматическая настройка

Скрипт `install.sh` автоматически определяет наличие Apache2 и предлагает настроить его как reverse proxy.

```bash
./install.sh --lang ru
```

При обнаружении Apache2 вы увидите:
```
✓ Apache2 установлен
Настроить Apache2 как reverse proxy? [y/n]:
```

Если вы ответите `y`, скрипт:
1. Создаст конфигурацию виртуального хоста
2. Включит необходимые модули (proxy, proxy_http)
3. Активирует сайт
4. Перезапустит Apache2

## Ручная настройка

### Шаг 1: Включите модули

```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod headers
```

### Шаг 2: Создайте конфигурацию

Создайте файл `/etc/apache2/sites-available/qemu-control.conf`:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    # Или ServerName localhost для локального доступа
    
    # Reverse proxy на Docker контейнер
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
    
    # Заголовки для корректной работы
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
    
    # Логи
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-access.log combined
</VirtualHost>
```

### Шаг 3: Для HTTPS (опционально)

Создайте конфигурацию для HTTPS:

```apache
<VirtualHost *:443>
    ServerName your-domain.com
    
    # SSL сертификаты
    SSLEngine on
    SSLCertificateFile /path/to/your/certificate.crt
    SSLCertificateKeyFile /path/to/your/private.key
    
    # Reverse proxy на Docker контейнер (HTTPS)
    ProxyPreserveHost On
    ProxyPass / https://localhost:8443/
    ProxyPassReverse / https://localhost:8443/
    
    # SSL Proxy
    SSLProxyEngine On
    SSLProxyVerify none
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerName off
    
    # Заголовки
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    
    # Логи
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-ssl-access.log combined
</VirtualHost>
```

Включите SSL модуль:
```bash
sudo a2enmod ssl
```

### Шаг 4: Активируйте сайт

```bash
# Активируйте конфигурацию
sudo a2ensite qemu-control.conf

# Проверьте конфигурацию
sudo apache2ctl configtest

# Перезапустите Apache2
sudo systemctl restart apache2
```

### Шаг 5: Отключите стандартный сайт (опционально)

```bash
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

## Конфигурация с доменным именем

Если у вас есть доменное имя:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    ServerAlias www.qemu.example.com
    
    # Redirect на HTTPS
    Redirect permanent / https://qemu.example.com/
</VirtualHost>

<VirtualHost *:443>
    ServerName qemu.example.com
    ServerAlias www.qemu.example.com
    
    # SSL сертификаты (Let's Encrypt)
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
    
    # Заголовки
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    RequestHeader set X-Forwarded-Host "qemu.example.com"
    
    # Логи
    ErrorLog ${APACHE_LOG_DIR}/qemu-control-error.log
    CustomLog ${APACHE_LOG_DIR}/qemu-control-access.log combined
</VirtualHost>
```

## Let's Encrypt SSL

### Установка Certbot

```bash
sudo apt-get install -y certbot python3-certbot-apache
```

### Получение сертификата

```bash
sudo certbot --apache -d qemu.example.com -d www.qemu.example.com
```

Certbot автоматически:
- Получит сертификат
- Настроит Apache2
- Настроит автообновление

### Проверка автообновления

```bash
sudo certbot renew --dry-run
```

## Настройка Laravel для работы за proxy

Если приложение работает за Apache2 proxy, обновите `.env`:

```env
APP_URL=https://qemu.example.com
```

И добавьте в `bootstrap/app.php` (если нужно):

```php
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->trustProxies(at: '*');
    })
    // ...
```

## Безопасность

### Ограничение доступа по IP

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Разрешить доступ только с определенных IP
    <Location />
        Require ip 192.168.1.0/24
        Require ip 10.0.0.0/8
    </Location>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

### Базовая аутентификация

```bash
# Создайте файл паролей
sudo htpasswd -c /etc/apache2/.htpasswd admin
```

Добавьте в конфигурацию:

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

### Защита от DDoS

Установите mod_evasive:

```bash
sudo apt-get install libapache2-mod-evasive
sudo a2enmod evasive
```

Настройте `/etc/apache2/mods-available/evasive.conf`:

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

## Мониторинг

### Логи Apache2

```bash
# Логи ошибок
sudo tail -f /var/log/apache2/qemu-control-error.log

# Логи доступа
sudo tail -f /var/log/apache2/qemu-control-access.log

# Все логи Apache2
sudo tail -f /var/log/apache2/*.log
```

### Статус Apache2

```bash
# Статус службы
sudo systemctl status apache2

# Проверка конфигурации
sudo apache2ctl configtest

# Список активных сайтов
sudo apache2ctl -S
```

## Производительность

### Кэширование

Включите mod_cache:

```bash
sudo a2enmod cache
sudo a2enmod cache_disk
```

Добавьте в конфигурацию:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Кэширование статики
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

### Сжатие

Включите mod_deflate:

```bash
sudo a2enmod deflate
```

Добавьте в конфигурацию:

```apache
<VirtualHost *:80>
    ServerName qemu.example.com
    
    # Сжатие
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript
    </IfModule>
    
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>
```

## Troubleshooting

### Ошибка 502 Bad Gateway

Проверьте:
1. Запущен ли Docker контейнер:
```bash
docker compose ps
```

2. Доступен ли порт 8080:
```bash
curl http://localhost:8080
```

3. Логи Apache2:
```bash
sudo tail -f /var/log/apache2/qemu-control-error.log
```

### Ошибка 503 Service Unavailable

Проверьте:
1. Правильность портов в конфигурации
2. Firewall не блокирует порты
3. SELinux разрешает proxy (на CentOS/RHEL)

### Медленная работа

1. Включите кэширование (см. выше)
2. Увеличьте таймауты:

```apache
ProxyTimeout 300
```

3. Оптимизируйте Apache2:

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

## Удаление конфигурации

```bash
# Отключите сайт
sudo a2dissite qemu-control.conf

# Удалите конфигурацию
sudo rm /etc/apache2/sites-available/qemu-control.conf

# Перезапустите Apache2
sudo systemctl reload apache2
```

## Полезные команды

```bash
# Перезапуск Apache2
sudo systemctl restart apache2

# Перезагрузка конфигурации без остановки
sudo systemctl reload apache2

# Проверка синтаксиса
sudo apache2ctl configtest

# Список модулей
sudo apache2ctl -M

# Включить модуль
sudo a2enmod module_name

# Отключить модуль
sudo a2dismod module_name

# Список сайтов
sudo apache2ctl -S
```

## Дополнительная информация

- [Apache2 Proxy Guide](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Laravel Behind Proxy](https://laravel.com/docs/11.x/requests#configuring-trusted-proxies)

---

**Языковые версии:** [APACHE.EN.md](../EN/APACHE.EN.md) | [APACHE.RU.md](APACHE.RU.md)
