#!/bin/bash

# Пример использования скрипта деплоя
# Этот файл показывает, как настроить и запустить автоматический деплой

echo "=== Пример настройки деплоя ==="

# 1. Копируем конфигурацию
echo "1. Копируем конфигурацию..."
cp ../../config/deploy.conf ../../config/deploy.conf.local

# 2. Редактируем конфигурацию
echo "2. Отредактируй файл ../../config/deploy.conf.local:"
echo "   - Укажи APP_DIR (директория приложения)"
echo "   - Укажи SERVICE_NAME (название systemd сервиса)"
echo "   - Настрой HEALTH_CHECK_URL"
echo "   - Укажи пути для логов и бэкапов"

# 3. Делаем скрипт исполняемым
echo "3. Делаем скрипт исполняемым..."
chmod +x ../../scripts/deploy/deploy.sh

# 4. Примеры использования
echo "4. Примеры использования:"
echo ""
echo "   # Деплой из директории"
echo "   sudo ../../scripts/deploy/deploy.sh /path/to/new/version/"
echo ""
echo "   # Деплой из архива"
echo "   sudo ../../scripts/deploy/deploy.sh /path/to/app.tar.gz"
echo ""
echo "   # Деплой из ZIP архива"
echo "   sudo ../../scripts/deploy/deploy.sh /path/to/app.zip"

# 5. Интеграция с CI/CD
echo "5. Для интеграции с CI/CD добавь в pipeline:"
echo "   - Сборка приложения"
echo "   - Создание архива"
echo "   - Копирование на сервер"
echo "   - Запуск скрипта деплоя"

echo ""
echo "=== Готово! ===" 