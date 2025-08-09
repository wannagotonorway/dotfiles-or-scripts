#!/bin/bash

# Утилита мониторинга состояния скриптов
# Автор: dotfiles-or-scripts
# Версия: 1.0

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Проверка статуса скриптов
check_scripts_status() {
    log_step "Проверка статуса скриптов..."
    
    local scripts=(
        "scripts/backup/backup.sh"
        "scripts/logs/rotate.sh"
        "scripts/deploy/deploy.sh"
        "scripts/healthcheck/check.sh"
    )
    
    local all_good=true
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            log "✓ $script готов к использованию"
        else
            log_error "✗ $script не найден или не исполняем"
            all_good=false
        fi
    done
    
    if [[ "$all_good" == "true" ]]; then
        log "Все скрипты готовы к работе"
    else
        log_warning "Некоторые скрипты требуют внимания"
    fi
    
    return $([[ "$all_good" == "true" ]] && echo 0 || echo 1)
}

# Проверка конфигурации
check_configuration() {
    log_step "Проверка конфигурации..."
    
    local configs=(
        "config/backup.conf.local"
        "config/logs.conf.local"
        "config/deploy.conf.local"
        "config/healthcheck.conf.local"
    )
    
    local configured=0
    local total=${#configs[@]}
    
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            log "✓ $config настроен"
            ((configured++))
        else
            log_warning "⚠ $config не настроен"
        fi
    done
    
    log "Настроено конфигов: $configured/$total"
    
    if [[ $configured -eq $total ]]; then
        log "Все конфиги настроены"
        return 0
    else
        log_warning "Некоторые конфиги требуют настройки"
        return 1
    fi
}

# Проверка cron задач
check_cron_jobs() {
    log_step "Проверка cron задач..."
    
    local current_dir=$(pwd)
    local cron_jobs=$(crontab -l 2>/dev/null | grep "$current_dir" || true)
    
    if [[ -n "$cron_jobs" ]]; then
        log "Найдены cron задачи:"
        echo "$cron_jobs" | while read -r job; do
            log "  $job"
        done
        return 0
    else
        log_warning "Cron задачи не найдены"
        log "Добавь задачи в crontab для автоматизации"
        return 1
    fi
}

# Проверка логов
check_logs() {
    log_step "Проверка логов..."
    
    local log_files=(
        "/var/log/backup.log"
        "/var/log/logrotate.log"
        "/var/log/deploy.log"
        "/var/log/healthcheck.log"
    )
    
    local logs_found=0
    local total=${#log_files[@]}
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size=$(du -h "$log_file" 2>/dev/null | cut -f1 || echo "0")
            local last_modified=$(stat -c %y "$log_file" 2>/dev/null | cut -d' ' -f1 || echo "неизвестно")
            log "✓ $log_file (размер: $size, обновлен: $last_modified)"
            ((logs_found++))
        else
            log_warning "⚠ $log_file не найден"
        fi
    done
    
    log "Найдено логов: $logs_found/$total"
}

# Проверка системных ресурсов
check_system_resources() {
    log_step "Проверка системных ресурсов..."
    
    # Дисковое пространство
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log_error "Дисковое пространство: $disk_usage% (критично!)"
    elif [[ $disk_usage -gt 80 ]]; then
        log_warning "Дисковое пространство: $disk_usage% (внимание)"
    else
        log "Дисковое пространство: $disk_usage% (норма)"
    fi
    
    # Память
    local memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    if [[ $(echo "$memory_usage > 90" | bc -l) -eq 1 ]]; then
        log_error "Использование памяти: ${memory_usage}% (критично!)"
    elif [[ $(echo "$memory_usage > 80" | bc -l) -eq 1 ]]; then
        log_warning "Использование памяти: ${memory_usage}% (внимание)"
    else
        log "Использование памяти: ${memory_usage}% (норма)"
    fi
    
    # Нагрузка CPU
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_int=$(echo "$cpu_load" | awk -F'.' '{print $1}')
    if [[ $cpu_int -gt 5 ]]; then
        log_warning "Нагрузка CPU: $cpu_load (высокая)"
    else
        log "Нагрузка CPU: $cpu_load (норма)"
    fi
}

# Проверка последних выполнений
check_recent_executions() {
    log_step "Проверка последних выполнений..."
    
    local current_dir=$(pwd)
    local cron_log="/var/log/cron"
    
    if [[ -f "$cron_log" ]]; then
        log "Последние cron задачи для dotfiles-or-scripts:"
        grep "$current_dir" "$cron_log" | tail -5 | while read -r line; do
            log "  $line"
        done
    else
        log_warning "Лог cron не найден"
    fi
}

# Показываем справку
show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --help, -h           Показать эту справку"
    echo "  --scripts            Только проверить скрипты"
    echo "  --config             Только проверить конфигурацию"
    echo "  --cron               Только проверить cron"
    echo "  --logs               Только проверить логи"
    echo "  --system             Только проверить системные ресурсы"
    echo "  --recent             Только проверить последние выполнения"
    echo ""
    echo "Примеры:"
    echo "  $0                   Полная проверка"
    echo "  $0 --scripts         Проверка скриптов"
    echo "  $0 --system          Проверка системы"
}

# Основная функция
main() {
    local check_scripts=true
    local check_config=true
    local check_cron=true
    local check_logs=true
    local check_system=true
    local check_recent=true
    
    # Парсим аргументы
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --scripts)
                check_config=false
                check_cron=false
                check_logs=false
                check_system=false
                check_recent=false
                shift
                ;;
            --config)
                check_scripts=false
                check_cron=false
                check_logs=false
                check_system=false
                check_recent=false
                shift
                ;;
            --cron)
                check_scripts=false
                check_config=false
                check_logs=false
                check_system=false
                check_recent=false
                shift
                ;;
            --logs)
                check_scripts=false
                check_config=false
                check_cron=false
                check_system=false
                check_recent=false
                shift
                ;;
            --system)
                check_scripts=false
                check_config=false
                check_cron=false
                check_logs=false
                check_recent=false
                shift
                ;;
            --recent)
                check_scripts=false
                check_config=false
                check_cron=false
                check_logs=false
                check_system=false
                shift
                ;;
            *)
                log_error "Неизвестный аргумент: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "=== Мониторинг dotfiles-or-scripts ==="
    echo ""
    
    local exit_code=0
    
    # Выполняем проверки
    if [[ "$check_scripts" == "true" ]]; then
        check_scripts_status || exit_code=1
        echo ""
    fi
    
    if [[ "$check_config" == "true" ]]; then
        check_configuration || exit_code=1
        echo ""
    fi
    
    if [[ "$check_cron" == "true" ]]; then
        check_cron_jobs || exit_code=1
        echo ""
    fi
    
    if [[ "$check_logs" == "true" ]]; then
        check_logs
        echo ""
    fi
    
    if [[ "$check_system" == "true" ]]; then
        check_system_resources
        echo ""
    fi
    
    if [[ "$check_recent" == "true" ]]; then
        check_recent_executions
        echo ""
    fi
    
    # Итоговый статус
    if [[ $exit_code -eq 0 ]]; then
        log "=== Все проверки пройдены успешно ==="
    else
        log_warning "=== Некоторые проверки завершились с предупреждениями ==="
    fi
    
    exit $exit_code
}

# Запуск
main "$@" 