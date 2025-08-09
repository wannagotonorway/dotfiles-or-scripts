#!/bin/bash

# Скрипт ротации логов
# Автор: dotfiles-or-scripts
# Версия: 1.0

set -euo pipefail

# Загружаем конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/logs.conf"

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
}

# Ротация логов по размеру
rotate_by_size() {
    local log_file="$1"
    local max_size="$2"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    local current_size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    local max_size_bytes=$((max_size * 1024 * 1024))  # Конвертируем в байты
    
    if [[ $current_size -gt $max_size_bytes ]]; then
        log "Ротация лога по размеру: $log_file (${current_size} байт)"
        
        # Создаем архив с timestamp
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local archive_name="${log_file}.${timestamp}.gz"
        
        if gzip -c "$log_file" > "$archive_name"; then
            # Очищаем основной лог
            : > "$log_file"
            log "Лог заархивирован: $archive_name"
        else
            log_error "Ошибка при архивировании: $log_file"
            return 1
        fi
    fi
}

# Ротация логов по времени
rotate_by_time() {
    local log_file="$1"
    local max_age="$2"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    # Проверяем возраст файла
    local file_age=$(find "$log_file" -mtime +"$max_age" -print -quit 2>/dev/null)
    
    if [[ -n "$file_age" ]]; then
        log "Ротация лога по времени: $log_file (старше $max_age дней)"
        
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local archive_name="${log_file}.${timestamp}.gz"
        
        if gzip -c "$log_file" > "$archive_name"; then
            : > "$log_file"
            log "Лог заархивирован: $archive_name"
        else
            log_error "Ошибка при архивировании: $log_file"
            return 1
        fi
    fi
}

# Очистка старых архивов
cleanup_old_archives() {
    log "Очистка старых архивов логов..."
    
    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ -d "$log_dir" ]]; then
            # Удаляем архивы старше указанного возраста
            find "$log_dir" -name "*.gz" -mtime +"$ARCHIVE_RETENTION_DAYS" -delete
            log "Очищены архивы в: $log_dir"
        fi
    done
}

# Проверка размера логов
check_log_sizes() {
    log "Проверка размера логов..."
    
    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ -d "$log_dir" ]]; then
            local total_size=$(du -sh "$log_dir" 2>/dev/null | cut -f1 || echo "0")
            log "Общий размер логов в $log_dir: $total_size"
            
            # Проверяем каждый лог файл
            while IFS= read -r -d '' log_file; do
                local size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
                local size_mb=$((size / 1024 / 1024))
                
                if [[ $size_mb -gt $MAX_LOG_SIZE_MB ]]; then
                    log "Большой лог файл: $log_file (${size_mb}MB)"
                fi
            done < <(find "$log_dir" -type f -name "*.log" -print0 2>/dev/null)
        fi
    done
}

# Основная функция ротации
main() {
    log "=== Начало ротации логов ==="
    
    check_directories
    
    # Ротация по размеру
    for log_file in "${LOG_FILES[@]}"; do
        if [[ -f "$log_file" ]]; then
            rotate_by_size "$log_file" "$MAX_LOG_SIZE_MB"
        fi
    done
    
    # Ротация по времени
    for log_file in "${LOG_FILES[@]}"; do
        if [[ -f "$log_file" ]]; then
            rotate_by_time "$log_file" "$MAX_LOG_AGE_DAYS"
        fi
    done
    
    # Очистка старых архивов
    cleanup_old_archives
    
    # Проверка размеров
    check_log_sizes
    
    log "=== Ротация логов завершена ==="
}

# Запуск
main "$@" 