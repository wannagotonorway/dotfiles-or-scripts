#!/bin/bash

# Скрипт проверки состояния сервисов
# Автор: dotfiles-or-scripts
# Версия: 1.0

set -euo pipefail

# Загружаем конфигурацию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config/healthcheck.conf"

# Функции логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$LOG_FILE"
}

# Проверяем существование директорий
check_directories() {
    if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
    fi
}

# Проверка состояния сервиса
check_service_status() {
    local service_name="$1"
    
    if systemctl is-active --quiet "$service_name"; then
        log "Сервис $service_name: АКТИВЕН"
        return 0
    else
        log_warning "Сервис $service_name: НЕ АКТИВЕН"
        return 1
    fi
}

# Проверка порта
check_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    if netstat -tuln | grep -q ":$port "; then
        log "Порт $port ($protocol): ОТКРЫТ"
        return 0
    else
        log_warning "Порт $port ($protocol): ЗАКРЫТ"
        return 1
    fi
}

# Проверка HTTP endpoint
check_http_endpoint() {
    local url="$1"
    local timeout="${2:-10}"
    
    if curl -f -s --max-time "$timeout" "$url" >/dev/null; then
        log "HTTP endpoint $url: ДОСТУПЕН"
        return 0
    else
        log_warning "HTTP endpoint $url: НЕ ДОСТУПЕН"
        return 1
    fi
}

# Проверка дискового пространства
check_disk_space() {
    local threshold="$1"
    
    local usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ $usage -gt $threshold ]]; then
        log_warning "Дисковое пространство: $usage% (превышает $threshold%)"
        return 1
    else
        log "Дисковое пространство: $usage% (норма)"
        return 0
    fi
}

# Проверка использования памяти
check_memory_usage() {
    local threshold="$1"
    
    local total=$(free -m | awk 'NR==2{print $2}')
    local used=$(free -m | awk 'NR==2{print $3}')
    local usage=$((used * 100 / total))
    
    if [[ $usage -gt $threshold ]]; then
        log_warning "Использование памяти: $usage% (превышает $threshold%)"
        return 1
    else
        log "Использование памяти: $usage% (норма)"
        return 0
    fi
}

# Проверка нагрузки CPU
check_cpu_load() {
    local threshold="$1"
    
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_int=$(echo "$load" | awk -F'.' '{print $1}')
    
    if [[ $load_int -gt $threshold ]]; then
        log_warning "Нагрузка CPU: $load (превышает $threshold)"
        return 1
    else
        log "Нагрузка CPU: $load (норма)"
        return 0
    fi
}

# Перезапуск сервиса
restart_service() {
    local service_name="$1"
    
    log "Перезапускаю сервис: $service_name"
    
    if systemctl restart "$service_name"; then
        log "Сервис $service_name перезапущен"
        
        # Ждем немного и проверяем
        sleep 5
        if check_service_status "$service_name"; then
            log "Сервис $service_name работает после перезапуска"
            return 0
        else
            log_error "Сервис $service_name не запустился после перезапуска"
            return 1
        fi
    else
        log_error "Ошибка при перезапуске сервиса $service_name"
        return 1
    fi
}

# Отправка уведомлений
send_notification() {
    local message="$1"
    local level="${2:-warning}"
    
    if [[ "$SEND_NOTIFICATIONS" == "true" ]]; then
        local subject="Health Check: $level"
        
        if command -v mail >/dev/null 2>&1; then
            echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL"
            log "Уведомление отправлено на $NOTIFICATION_EMAIL"
        fi
    fi
}

# Основная функция проверки
main() {
    log "=== Начало проверки состояния ==="
    
    check_directories
    
    local issues_found=0
    
    # Проверяем сервисы
    for service in "${SERVICES[@]}"; do
        if ! check_service_status "$service"; then
            ((issues_found++))
            
            if [[ "$AUTO_RESTART" == "true" ]]; then
                if restart_service "$service"; then
                    log "Проблема с сервисом $service решена"
                    ((issues_found--))
                fi
            fi
        fi
    done
    
    # Проверяем порты
    for port_info in "${PORTS[@]}"; do
        IFS=':' read -r port protocol <<< "$port_info"
        if [[ -z "$protocol" ]]; then
            protocol="tcp"
        fi
        
        if ! check_port "$port" "$protocol"; then
            ((issues_found++))
        fi
    done
    
    # Проверяем HTTP endpoints
    for url in "${HTTP_ENDPOINTS[@]}"; do
        if ! check_http_endpoint "$url"; then
            ((issues_found++))
        fi
    done
    
    # Проверяем системные ресурсы
    if ! check_disk_space "$DISK_THRESHOLD"; then
        ((issues_found++))
    fi
    
    if ! check_memory_usage "$MEMORY_THRESHOLD"; then
        ((issues_found++))
    fi
    
    if ! check_cpu_load "$CPU_THRESHOLD"; then
        ((issues_found++))
    fi
    
    # Отправляем уведомления если есть проблемы
    if [[ $issues_found -gt 0 ]]; then
        local message="Обнаружено $issues_found проблем в системе. Проверьте логи: $LOG_FILE"
        send_notification "$message" "error"
        log_warning "=== Проверка завершена с $issues_found проблемами ===""
        exit 1
    else
        log "=== Все проверки пройдены успешно ===""
        exit 0
    fi
}

# Запуск
main "$@" 