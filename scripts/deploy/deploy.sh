#!/bin/bash

# Скрипт автоматического деплоя
# Автор: dotfiles-or-scripts
# Версия: 1.0

set -euo pipefail

# Загружаем конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/deploy.conf"

# Функции логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Проверяем существование директорий
check_directories() {
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
    
    if [[ ! -d "$DEPLOY_DIR" ]]; then
        mkdir -p "$DEPLOY_DIR"
    fi
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

# Создание бэкапа текущей версии
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="deploy_backup_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "Создаю бэкап текущей версии..."
    
    if [[ -d "$APP_DIR" ]]; then
        if tar -czf "$backup_path" -C "$(dirname "$APP_DIR")" "$(basename "$APP_DIR")"; then
            log "Бэкап создан: $backup_name"
            echo "$backup_path"
        else
            log_error "Ошибка при создании бэкапа"
            return 1
        fi
    else
        log "Директория приложения не существует, бэкап пропущен"
        echo ""
    fi
}

# Остановка сервиса
stop_service() {
    if [[ -n "$SERVICE_NAME" ]]; then
        log "Останавливаю сервис: $SERVICE_NAME"
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            if systemctl stop "$SERVICE_NAME"; then
                log "Сервис остановлен"
            else
                log_error "Ошибка при остановке сервиса"
                return 1
            fi
        else
            log "Сервис уже остановлен"
        fi
    fi
}

# Запуск сервиса
start_service() {
    if [[ -n "$SERVICE_NAME" ]]; then
        log "Запускаю сервис: $SERVICE_NAME"
        
        if systemctl start "$SERVICE_NAME"; then
            log "Сервис запущен"
        else
            log_error "Ошибка при запуске сервиса"
            return 1
        fi
    fi
}

# Проверка health check
health_check() {
    if [[ -n "$HEALTH_CHECK_URL" ]]; then
        log "Проверяю health check..."
        
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if curl -f -s "$HEALTH_CHECK_URL" >/dev/null; then
                log "Health check пройден успешно"
                return 0
            fi
            
            log "Попытка $attempt/$max_attempts - health check не пройден, жду..."
            sleep 2
            ((attempt++))
        done
        
        log_error "Health check не пройден после $max_attempts попыток"
        return 1
    else
        log "Health check пропущен (не настроен)"
        return 0
    fi
}

# Деплой новой версии
deploy_new_version() {
    local source_path="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log "Начинаю деплой новой версии..."
    
    # Останавливаем сервис
    stop_service
    
    # Создаем бэкап
    local backup_path=$(create_backup)
    
    # Удаляем старую версию
    if [[ -d "$APP_DIR" ]]; then
        log "Удаляю старую версию..."
        rm -rf "$APP_DIR"
    fi
    
    # Копируем новую версию
    log "Копирую новую версию..."
    if [[ -d "$source_path" ]]; then
        cp -r "$source_path" "$APP_DIR"
    elif [[ -f "$source_path" ]]; then
        # Если это архив
        if [[ "$source_path" == *.tar.gz ]]; then
            tar -xzf "$source_path" -C "$(dirname "$APP_DIR")"
        elif [[ "$source_path" == *.zip ]]; then
            unzip "$source_path" -d "$(dirname "$APP_DIR")"
        fi
    fi
    
    # Устанавливаем права
    if [[ -d "$APP_DIR" ]]; then
        chmod -R 755 "$APP_DIR"
        log "Права установлены"
    fi
    
    # Запускаем сервис
    start_service
    
    # Проверяем health check
    if health_check; then
        log "Деплой завершен успешно"
        return 0
    else
        log_error "Health check не пройден, начинаю rollback"
        rollback "$backup_path"
        return 1
    fi
}

# Rollback к предыдущей версии
rollback() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" || ! -f "$backup_path" ]]; then
        log_error "Бэкап для rollback не найден"
        return 1
    fi
    
    log "=== Начинаю ROLLBACK ==="
    
    # Останавливаем сервис
    stop_service
    
    # Удаляем текущую версию
    if [[ -d "$APP_DIR" ]]; then
        rm -rf "$APP_DIR"
    fi
    
    # Восстанавливаем из бэкапа
    log "Восстанавливаю из бэкапа: $backup_path"
    tar -xzf "$backup_path" -C "$(dirname "$APP_DIR")"
    
    # Запускаем сервис
    start_service
    
    # Проверяем health check
    if health_check; then
        log "Rollback завершен успешно"
        return 0
    else
        log_error "Rollback не удался - health check не пройден"
        return 1
    fi
}

# Основная функция
main() {
    local source_path="$1"
    
    if [[ -z "$source_path" ]]; then
        log_error "Не указан путь к исходным файлам"
        echo "Использование: $0 <путь_к_файлам>"
        exit 1
    fi
    
    if [[ ! -e "$source_path" ]]; then
        log_error "Источник не найден: $source_path"
        exit 1
    fi
    
    log "=== Начало деплоя ==="
    log "Источник: $source_path"
    log "Цель: $APP_DIR"
    
    check_directories
    
    # Выполняем деплой
    if deploy_new_version "$source_path"; then
        log "=== Деплой завершен успешно ==="
        exit 0
    else
        log_error "=== Деплой завершился с ошибками ==="
        exit 1
    fi
}

# Запуск
main "$@" 