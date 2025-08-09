#!/bin/bash

# Скрипт автоматического резервного копирования
# Автор: dotfiles-or-scripts
# Версия: 1.0

set -euo pipefail

# Загружаем конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/backup.conf"

# Функции логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# Проверяем существование директорий
check_directories() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "Создана директория для бэкапов: $BACKUP_DIR"
    fi
    
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
}

# Бэкап файлов
backup_files() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="files_backup_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "Начинаю бэкап файлов..."
    
    if tar -czf "$backup_path" -C / "$BACKUP_PATHS" 2>/dev/null; then
        log "Бэкап файлов создан: $backup_name"
        
        # Проверяем размер
        local size=$(du -h "$backup_path" | cut -f1)
        log "Размер бэкапа: $size"
        
        # Шифруем если включено
        if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
            gpg --encrypt --recipient "$GPG_RECIPIENT" "$backup_path"
            rm "$backup_path"
            log "Бэкап зашифрован: ${backup_name}.gpg"
        fi
    else
        log_error "Ошибка при создании бэкапа файлов"
        return 1
    fi
}

# Бэкап базы данных
backup_database() {
    if [[ -z "$DB_HOST" ]]; then
        log "Бэкап БД пропущен (не настроен)"
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="db_backup_${timestamp}.sql.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "Начинаю бэкап базы данных..."
    
    if mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$backup_path"; then
        log "Бэкап БД создан: $backup_name"
        
        local size=$(du -h "$backup_path" | cut -f1)
        log "Размер бэкапа БД: $size"
    else
        log_error "Ошибка при создании бэкапа БД"
        return 1
    fi
}

# Ротация старых бэкапов
rotate_backups() {
    log "Проверяю старые бэкапы..."
    
    # Удаляем файлы старше указанного возраста
    find "$BACKUP_DIR" -name "*.tar.gz*" -mtime +"$BACKUP_RETENTION_DAYS" -delete
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$BACKUP_RETENTION_DAYS" -delete
    
    log "Ротация завершена"
}

# Отправка уведомлений
send_notification() {
    if [[ "$SEND_NOTIFICATIONS" == "true" ]]; then
        local subject="Бэкап завершен"
        local body="Бэкап успешно завершен в $(date '+%Y-%m-%d %H:%M:%S')"
        
        if command -v mail >/dev/null 2>&1; then
            echo "$body" | mail -s "$subject" "$NOTIFICATION_EMAIL"
            log "Уведомление отправлено на $NOTIFICATION_EMAIL"
        fi
    fi
}

# Основная функция
main() {
    log "=== Начало процесса бэкапа ==="
    
    check_directories
    
    # Создаем бэкапы
    if backup_files && backup_database; then
        log "Все бэкапы созданы успешно"
        
        # Ротация
        rotate_backups
        
        # Уведомления
        send_notification
        
        log "=== Бэкап завершен успешно ==="
    else
        log_error "Бэкап завершился с ошибками"
        exit 1
    fi
}

# Запуск
main "$@" 