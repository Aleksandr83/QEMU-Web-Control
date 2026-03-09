# Автозапуск виртуальных машин

## Обзор

Функция автозапуска позволяет автоматически запускать выбранные виртуальные машины при загрузке системы Linux.

## Настройка

### 1. Отметить ВМ для автозапуска

В веб-интерфейсе при создании или редактировании виртуальной машины:
1. Откройте форму создания/редактирования ВМ
2. Установите флажок **"Запускать автоматически при старте системы"**
3. Сохраните изменения

### 2. Установить службу автозапуска

```bash
# На русском языке
./scripts/autostart-service.sh --install --lang ru

# На английском языке
./scripts/autostart-service.sh --install
```

Служба автоматически:
- Создаст systemd unit файл
- Настроит зависимость от Docker
- Включит автоматический запуск при загрузке системы

### 3. Проверить статус службы

```bash
./scripts/autostart-service.sh --status --lang ru
```

или напрямую через systemd:

```bash
sudo systemctl status qemu-autostart.service
```

## Использование

### Ручной запуск автозапуска

Запустить все ВМ с включенным автозапуском вручную:

```bash
docker compose exec app php artisan vm:autostart
```

или через службу:

```bash
sudo systemctl start qemu-autostart.service
```

### Проверка списка ВМ с автозапуском

Зайдите в веб-интерфейс:
- ВМ с автозапуском помечены синим значком часов ⏰
- В списке виртуальных машин видно, какие ВМ будут автоматически запускаться

## Управление службой

### Включить службу

```bash
sudo systemctl enable qemu-autostart.service
```

### Отключить службу

```bash
sudo systemctl disable qemu-autostart.service
```

### Запустить службу вручную

```bash
sudo systemctl start qemu-autostart.service
```

### Остановить службу

```bash
sudo systemctl stop qemu-autostart.service
```

### Удалить службу

```bash
./scripts/autostart-service.sh --uninstall --lang ru
```

## Логи

### Просмотр логов службы

```bash
sudo journalctl -u qemu-autostart.service
```

### Просмотр последних логов

```bash
sudo journalctl -u qemu-autostart.service -n 50
```

### Следить за логами в реальном времени

```bash
sudo journalctl -u qemu-autostart.service -f
```

## Устранение неполадок

### Служба не запускается

1. Проверьте, запущен ли Docker:
```bash
sudo systemctl status docker
```

2. Проверьте, запущены ли контейнеры приложения:
```bash
docker compose ps
```

3. Проверьте логи службы:
```bash
sudo journalctl -u qemu-autostart.service -n 100
```

### ВМ не запускаются автоматически

1. Убедитесь, что у ВМ включен флаг автозапуска в веб-интерфейсе

2. Проверьте статус ВМ вручную:
```bash
docker compose exec app php artisan vm:autostart
```

3. Проверьте права доступа к дискам ВМ:
```bash
ls -la /var/lib/qemu/vms/
```

### Служба запускается, но ничего не происходит

Убедитесь, что есть хотя бы одна ВМ с включенным автозапуском:
```bash
docker compose exec app php artisan tinker
>>> \App\Models\VirtualMachine::where('autostart', true)->get();
```

## Примеры

### Пример 1: Сервер разработки

У вас есть ВМ с базой данных, которая должна быть всегда доступна:

1. Создайте ВМ "Development Database"
2. Включите автозапуск
3. Установите службу автозапуска
4. При каждой перезагрузке сервера ВМ будет запускаться автоматически

### Пример 2: Тестовое окружение

Несколько ВМ для тестирования, которые нужны постоянно:

1. Создайте ВМ: "Test Web Server", "Test DB", "Test Cache"
2. Включите автозапуск для всех трех
3. При загрузке системы все три ВМ запустятся автоматически

### Пример 3: Выборочный автозапуск

У вас 10 ВМ, но автоматически нужны только 2:

1. Создайте все 10 ВМ
2. Включите автозапуск только для нужных 2 ВМ
3. Остальные 8 запускайте вручную по необходимости

## Технические детали

### Как это работает

1. При загрузке системы запускается systemd
2. После запуска Docker запускается служба `qemu-autostart.service`
3. Служба выполняет команду `php artisan vm:autostart`
4. Команда находит все ВМ с `autostart = true` и статусом `stopped`
5. Для каждой ВМ вызывается `QemuService::start()`
6. ВМ запускаются последовательно

### Файл службы

Расположение: `/etc/systemd/system/qemu-autostart.service`

```ini
[Unit]
Description=QEMU Web Control - Autostart Virtual Machines
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/QemuWebControl
ExecStart=/usr/bin/docker compose exec -T app php artisan vm:autostart
User=your-username
Group=your-group

[Install]
WantedBy=multi-user.target
```

### Artisan команда

Команда: `php artisan vm:autostart`

Исходный код: `app/Console/Commands/AutostartVirtualMachines.php`

Логика:
1. Находит все ВМ где `autostart = true` и `status = stopped`
2. Вызывает `QemuService::start()` для каждой ВМ
3. Логирует результаты (успешно/неудачно)
4. Обновляет статус ВМ в базе данных

## Рекомендации

### Безопасность

- Не включайте автозапуск для всех ВМ - это увеличит время загрузки системы
- Убедитесь, что у ВМ достаточно ресурсов (CPU, RAM) на хосте
- Проверяйте логи после перезагрузки системы

### Производительность

- Запуск нескольких ВМ одновременно может быть ресурсоемким
- Рассмотрите последовательный запуск с задержками (модифицируйте команду)
- Мониторьте использование ресурсов хоста

### Надежность

- Регулярно проверяйте статус службы
- Настройте мониторинг для критичных ВМ
- Имейте план резервного копирования дисков ВМ

## FAQ

**Q: Можно ли настроить порядок запуска ВМ?**  
A: В текущей версии ВМ запускаются в порядке их ID. Для изменения порядка модифицируйте команду `vm:autostart`.

**Q: Что если ВМ не запустится при автозапуске?**  
A: Служба продолжит работу, но ВМ останется в статусе `stopped`. Проверьте логи для диагностики.

**Q: Сколько времени занимает автозапуск?**  
A: Зависит от количества ВМ и ресурсов системы. Обычно 2-5 секунд на одну ВМ.

**Q: Можно ли автоматически останавливать ВМ при выключении?**  
A: В текущей версии нет, но Docker остановит контейнеры, что остановит и ВМ.

**Q: Работает ли автозапуск в Docker Swarm/Kubernetes?**  
A: Текущая реализация рассчитана на docker-compose. Для оркестраторов нужна адаптация.

## Поддержка

При проблемах:
1. Проверьте логи: `sudo journalctl -u qemu-autostart.service`
2. Проверьте статус Docker: `sudo systemctl status docker`
3. Запустите команду вручную: `docker compose exec app php artisan vm:autostart`
4. Проверьте права доступа к `/var/lib/qemu/vms/`
