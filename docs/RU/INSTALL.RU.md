# Быстрая установка QEMU Web Control

## Требования
- Linux (Debian/Ubuntu, Orange Pi RV2)
- Docker (устанавливается автоматически)
- QEMU/KVM на хосте

**Для RISC-V (Orange Pi, VisionFive)**: См. [RISCV-QUICKSTART.RU.md](RISCV-QUICKSTART.RU.md) / [RISCV-QUICKSTART.EN.md](../EN/RISCV-QUICKSTART.EN.md)

## Установка

```bash
# Клонируйте или перейдите в директорию проекта
cd QemuWebControl

# Запустите установку
chmod +x install.sh
./install.sh

# Или на русском языке
./install.sh --lang ru
```

**⚠️ Важно для RISC-V:**
- Установка займет 20-30 минут
- Сборка образов - самая долгая часть
- Если что-то не работает - см. [TROUBLESHOOTING.EN.md](../EN/TROUBLESHOOTING.EN.md) / [TROUBLESHOOTING.RU.md](TROUBLESHOOTING.RU.md)

**💡 Совет:**
- При вводе параметров значения по умолчанию показаны в `[квадратных скобках]`
- Просто нажмите Enter для использования значения по умолчанию
- Примеры установки: [INSTALL-EXAMPLE.RU.md](INSTALL-EXAMPLE.RU.md) / [INSTALL-EXAMPLE.EN.md](../EN/INSTALL-EXAMPLE.EN.md)

## После установки

Приложение будет доступно по адресу:
- HTTP: http://localhost:8080
- HTTPS: https://localhost:8443

### Учетные данные

**Администратор:**
- Логин: admin
- Пароль: admin

## Выбор базы данных

При установке доступны два варианта:

**[1] Docker MariaDB** (x86_64, amd64, aarch64)
- MariaDB запускается в отдельном контейнере
- База создаётся автоматически
- Не требует установки MariaDB на хост
- **Не поддерживается на RISC-V** (Orange Pi, VisionFive)

**[2] Внешняя MariaDB/MySQL**
- Использует существующую MariaDB/MySQL на хосте
- Доступны режимы: Host Network (localhost) или Bridge (gateway IP)
- Требуется на RISC-V
- Рекомендуется для production (безопасность)

## Управление

```bash
./start.sh      # Запустить
./stop.sh       # Остановить
./restart.sh    # Перезапустить
./uninstall.sh  # Удалить
```

## Полезные скрипты

```bash
./scripts/diagnose.sh          # Диагностика системы
./scripts/setup-database.sh    # Настройка базы данных
./scripts/autostart-service.sh # Управление автозапуском ВМ
```

## Настройка QEMU

Установщик создаёт директории `/var/qemu/VM`, `/var/lib/qemu/iso`, `/srv/iso`.

Скопируйте ISO образы в `/var/lib/qemu/iso/` или `/srv/iso/`. При создании ВМ укажите путь к ISO, например: `/var/lib/qemu/iso/ubuntu.iso`.

## Настройка автозапуска ВМ (опционально)

Если вы хотите, чтобы виртуальные машины с включенным автозапуском запускались при загрузке системы:

```bash
# Установить службу автозапуска
./scripts/autostart-service.sh --install --lang ru

# Проверить статус
./scripts/autostart-service.sh --status

# Отметьте нужные ВМ для автозапуска в веб-интерфейсе
```

## Подробная документация

- [English README](../../README.md)
- [Русская документация](../../README.RU.md)

---

**Языковые версии:** [INSTALL.EN.md](../EN/INSTALL.EN.md) | [INSTALL.RU.md](INSTALL.RU.md)
