#!/bin/bash

# Пример использования скрипта бэкапов
# Этот файл показывает, как настроить и запустить бэкапы

echo "=== Пример настройки бэкапов ==="

# 1. Копируем конфигурацию
echo "1. Копируем конфигурацию..."
cp ../../config/backup.conf ../../config/backup.conf.local

# 2. Редактируем конфигурацию
echo "2. Отредактируй файл ../../config/backup.conf.local:"
echo "   - Укажи BACKUP_DIR"
echo "   - Настрой BACKUP_PATHS"
echo "   - Укажи параметры БД если нужно"
echo "   - Настрой уведомления"

# 3. Делаем скрипт исполняемым
echo "3. Делаем скрипт исполняемым..."
chmod +x ../../scripts/backup/backup.sh

# 4. Тестовый запуск
echo "4. Тестовый запуск (с правами sudo):"
echo "   sudo ../../scripts/backup/backup.sh"

# 5. Добавление в cron
echo "5. Добавь в cron для автоматического запуска:"
echo "   crontab -e"
echo "   # Бэкап каждый день в 2:00"
echo "   0 2 * * * /path/to/scripts/backup/backup.sh"

echo ""
echo "=== Готово! ===" 