# Changelog

## [0.0.3] - 2026-03-16

### Добавлено
- **Bridge: выбор сетевого интерфейса** — В настройках ВМ (создание/редактирование) при типе сети Bridge можно выбрать физический интерфейс (например enp0s3). Интерфейс сохраняется в БД; при запуске ВМ сервис определяет мост по `bridge link show`.
- **Вкладка логов: QemuControlService** — Новая вкладка «QemuControlService» на странице Логов показывает последние 500 строк лога C++-сервиса (через HTTP GET /logs). Автообновление каждые 5 секунд, кнопка копирования, очистка лога.

### Изменено
- **Список интерфейсов** — GET /interfaces возвращает только физические адаптеры; виртуальные (lo, veth*, docker*, virbr*, vnet*, br-*, tap*, tun*) исключены.
- **Определение моста** — Список строится из `ip link show`; принадлежность к мосту — через `bridge link show`. Интерфейсы вне моста также отображаются (с пустым bridge).
- **Логирование** — QemuControlService логирует используемый мост и способ его определения (по интерфейсу, первый мост или br0 по умолчанию).

### Исправлено
- Режим Bridge: ВМ с типом сети Bridge теперь корректно запускаются; список мостов загружается с хоста.
- Blade: отсутствовал `@endif` для `@if` в представлении activity-logs index.

## [0.0.2] - 2026-02-06

### ⚠️ Важное примечание

Установка на RISC-V (Orange Pi RV2):
- Сборка займет 20-30 минут

### Добавлено
- ✅ **Автозапуск виртуальных машин** при старте системы
  - Новое поле `autostart` в БД
  - Artisan команда `vm:autostart`
  - Systemd служба для автозапуска
  - Скрипт управления `autostart-service.sh`
  - Индикатор автозапуска в интерфейсе
  - Документация: `AUTOSTART.EN.md` / `AUTOSTART.RU.md`

- ✅ **Поддержка RISC-V архитектуры** (Orange Pi RV2, VisionFive, Milk-V)
  - Адаптированный Dockerfile для PHP с Node.js для RISC-V
  - Dockerfile для Nginx на Alpine
  - Поддержка MariaDB для RISC-V
  - Автоматическая установка `docker.io` на RISC-V
  - Документация: `RISCV.EN.md` / `RISCV.RU.md`, `RISCV-QUICKSTART.EN.md` / `RISCV-QUICKSTART.RU.md`

- ✅ **Совместимость с docker-compose**
  - Поддержка `docker compose` (плагин)
  - Поддержка `docker-compose` (standalone)
  - Автоматическое определение доступной версии

- ✅ **Улучшения install.sh**
  - Автоматическая настройка Apache2 как reverse proxy
  - Автоматическое создание базы данных MySQL/MariaDB
  - Проверка и установка mysql клиента
  - Назначение привилегий пользователю БД

- ✅ **Документация**
  - `COMMANDS.EN.md` / `COMMANDS.RU.md` - справочник всех команд (EN/RU)
  - `AUTOSTART.EN.md` / `AUTOSTART.RU.md` - руководство по автозапуску (EN/RU)
  - `RISCV.EN.md` / `RISCV.RU.md` - полное руководство для RISC-V
  - `RISCV-QUICKSTART.EN.md` / `RISCV-QUICKSTART.RU.md` - быстрый старт на RISC-V
  - `APACHE.EN.md` / `APACHE.RU.md` - настройка Apache2 reverse proxy
  - `TROUBLESHOOTING.EN.md` / `TROUBLESHOOTING.RU.md` - решение проблем (ВАЖНО!)
  - `CHANGELOG.EN.md` / `CHANGELOG.RU.md` - история изменений (EN/RU)
  - `diagnose.sh` - скрипт диагностики системы

### Изменено
- Улучшена функция установки Docker в `install.sh`
  - Автоматическое определение архитектуры
  - Установка `docker.io` на RISC-V
  - Установка официального Docker на x86_64/ARM64
  - Проверка обеих версий docker-compose

- Обновлены все управляющие скрипты
  - `start.sh`, `stop.sh`, `restart.sh`, `uninstall.sh`
  - Автоматическое определение `docker compose` vs `docker-compose`

- Обновлена документация
  - `README.md` и `README.RU.md` с информацией о RISC-V
  - `INSTALL.EN.md` / `INSTALL.RU.md` с ссылками на RISC-V инструкции

### Исправлено
- ❌ Ошибка установки Docker на RISC-V (пакет не найден)
- ❌ Ошибка "no matching manifest" для Nginx и MariaDB на RISC-V
- ❌ Отсутствие Node.js в контейнере на RISC-V
- ❌ Несовместимость с разными версиями docker-compose

## [0.0.1] - 2026-02-06

### Добавлено
- ✅ Начальный релиз QEMU Web Control
- ✅ Laravel 11 с PHP 8.3
- ✅ Docker конфигурация (Nginx, PHP-FPM, MariaDB, Scheduler)
- ✅ Система аутентификации и авторизации
- ✅ Управление ролями (Administrator, User)
- ✅ CRUD для виртуальных машин
- ✅ Управление ВМ (старт, стоп, перезапуск)
- ✅ Мультиязычность (английский, русский)
- ✅ Темный интерфейс с Tailwind CSS
- ✅ Журнал действий (Activity Log)
- ✅ SSL сертификаты (самоподписанные)
- ✅ Интерактивный установщик `install.sh`
- ✅ Управляющие скрипты (start, stop, restart, uninstall)
- ✅ Sticky footer во всех layouts
- ✅ Защита системных ролей
- ✅ Защита последнего администратора
- ✅ Правильные права доступа Docker (UID 1000)
- ✅ Локализация bash скриптов
- ✅ Форматированный вывод с UTF-8 поддержкой

---

## Миграция

### С версии 0.0.2 на 0.0.3

1. Обновите файлы проекта
2. Запустите миграцию:
```bash
docker compose exec app php artisan migrate
```
3. Пересоберите QemuControlService (если собираете из исходников):
```bash
cd services/QemuControlService/build && cmake .. && make && sudo systemctl restart QemuControlService
```

### С версии 0.0.1 на 0.0.2

1. Обновите файлы проекта
2. Запустите новую миграцию:
```bash
docker compose exec app php artisan migrate
```

3. Если используете RISC-V, пересоберите образы:
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

4. (Опционально) Установите службу автозапуска:
```bash
./scripts/autostart-service.sh --install --lang ru
```

---

## Известные проблемы

### RISC-V
- Сборка образов занимает 20-30 минут (это нормально)
- MariaDB может работать медленнее чем на x86_64
- Некоторые NPM пакеты могут не иметь prebuilt бинарников

### Общие
- VNC для ВМ требует дополнительной настройки
- Эмуляция x86 ВМ на RISC-V работает медленно

---

## Планы на будущее

- [ ] Web VNC клиент для доступа к ВМ
- [ ] Управление пользователями через интерфейс
- [ ] Статистика использования ресурсов ВМ
- [ ] Snapshots виртуальных машин
- [ ] Клонирование ВМ
- [ ] Импорт/экспорт ВМ
- [ ] REST API для управления
---

## Благодарности

Спасибо всем, кто тестирует и использует QEMU Web Control!

Особая благодарность сообществу RISC-V за поддержку и тестирование на Orange Pi RV2.
