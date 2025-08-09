#!/bin/bash

# Скрипт установки dotfiles-or-scripts
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

# Проверка зависимостей
check_dependencies() {
    log_step "Проверка зависимостей..."
    
    local missing_deps=()
    
    # Проверяем bash версию
    if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
        missing_deps+=("bash 4.0+")
    fi
    
    # Проверяем необходимые команды
    local required_commands=("tar" "gzip" "find" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Отсутствуют зависимости: ${missing_deps[*]}"
        log "Установите недостающие пакеты и повторите установку"
        exit 1
    fi
    
    log "Все зависимости установлены"
}

# Создание структуры директорий
create_directories() {
    log_step "Создание структуры директорий..."
    
    local dirs=(
        "logs"
        "config"
        "examples"
        "scripts/backup"
        "scripts/logs"
        "scripts/deploy"
        "scripts/healthcheck"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "Создана директория: $dir"
        fi
    done
}

# Установка прав на выполнение
set_permissions() {
    log_step "Установка прав на выполнение..."
    
    local scripts=(
        "scripts/backup/backup.sh"
        "scripts/logs/rotate.sh"
        "scripts/deploy/deploy.sh"
        "scripts/healthcheck/check.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log "Установлены права на выполнение: $script"
        fi
    done
}

# Создание примеров конфигурации
setup_configs() {
    log_step "Настройка конфигурации..."
    
    # Создаем локальные копии конфигов
    local configs=(
        "config/backup.conf:config/backup.conf.local"
        "config/logs.conf:config/logs.conf.local"
        "config/deploy.conf:config/deploy.conf.local"
        "config/healthcheck.conf:config/healthcheck.conf.local"
    )
    
    for config_pair in "${configs[@]}"; do
        IFS=':' read -r source dest <<< "$config_pair"
        if [[ -f "$source" && ! -f "$dest" ]]; then
            cp "$source" "$dest"
            log "Создан локальный конфиг: $dest"
        fi
    done
}

# Создание cron задач
setup_cron() {
    log_step "Настройка cron задач..."
    
    local current_dir=$(pwd)
    local cron_file="/tmp/dotfiles_cron_$$"
    
    cat > "$cron_file" << EOF
# Автоматические задачи для dotfiles-or-scripts
# Добавь эти строки в crontab: crontab -e

# Бэкапы каждый день в 2:00
0 2 * * * $current_dir/scripts/backup/backup.sh

# Ротация логов каждые 6 часов
0 */6 * * * $current_dir/scripts/logs/rotate.sh

# Healthcheck каждые 5 минут
*/5 * * * * $current_dir/scripts/healthcheck/check.sh

# Деплой по требованию (ручной запуск)
# $current_dir/scripts/deploy/deploy.sh <путь_к_файлам>
EOF
    
    log "Файл с cron задачами создан: $cron_file"
    log_warning "Добавь содержимое в crontab командой: crontab $cron_file"
}

# Проверка установки
verify_installation() {
    log_step "Проверка установки..."
    
    local errors=0
    
    # Проверяем скрипты
    local scripts=(
        "scripts/backup/backup.sh"
        "scripts/logs/rotate.sh"
        "scripts/deploy/deploy.sh"
        "scripts/healthcheck/check.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && -x "$script" ]]; then
            log "✓ $script готов к использованию"
        else
            log_error "✗ $script не найден или не исполняем"
            ((errors++))
        fi
    done
    
    # Проверяем конфиги
    local configs=(
        "config/backup.conf.local"
        "config/logs.conf.local"
        "config/deploy.conf.local"
        "config/healthcheck.conf.local"
    )
    
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            log "✓ $config создан"
        else
            log_warning "⚠ $config не найден (создай вручную)"
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log "Установка завершена успешно!"
    else
        log_error "Установка завершена с $errors ошибками"
        exit 1
    fi
}

# Показываем справку
show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --help, -h     Показать эту справку"
    echo "  --no-cron      Пропустить настройку cron"
    echo "  --verify       Только проверить установку"
    echo ""
    echo "Примеры:"
    echo "  $0              Полная установка"
    echo "  $0 --no-cron    Установка без cron"
    echo "  $0 --verify     Проверка установки"
}

# Основная функция
main() {
    local setup_cron_flag=true
    local verify_only=false
    
    # Парсим аргументы
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --no-cron)
                setup_cron_flag=false
                shift
                ;;
            --verify)
                verify_only=true
                shift
                ;;
            *)
                log_error "Неизвестный аргумент: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "=== Установка dotfiles-or-scripts ==="
    echo ""
    
    if [[ "$verify_only" == "true" ]]; then
        verify_installation
        exit 0
    fi
    
    # Выполняем установку
    check_dependencies
    create_directories
    set_permissions
    setup_configs
    
    if [[ "$setup_cron_flag" == "true" ]]; then
        setup_cron
    fi
    
    verify_installation
    
    echo ""
    echo "=== Следующие шаги ==="
    echo "1. Отредактируй конфигурационные файлы в config/"
    echo "2. Протестируй скрипты вручную"
    echo "3. Добавь cron задачи для автоматизации"
    echo "4. Настрой мониторинг и уведомления"
    echo ""
    echo "Документация: README.md"
    echo "Примеры: examples/"
}

# Запуск
main "$@" 