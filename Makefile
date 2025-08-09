# Makefile для dotfiles-or-scripts
# Автор: dotfiles-or-scripts
# Версия: 1.0

.PHONY: help install install-no-cron verify monitor clean test backup logs deploy healthcheck

# Переменные
SCRIPTS_DIR = scripts
CONFIG_DIR = config
EXAMPLES_DIR = examples
LOGS_DIR = logs

# Цвета для вывода
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Справка по умолчанию
help:
	@echo "$(BLUE)=== dotfiles-or-scripts - Makefile ===$(NC)"
	@echo ""
	@echo "$(GREEN)Доступные команды:$(NC)"
	@echo "  $(YELLOW)install$(NC)          - Полная установка с cron"
	@echo "  $(YELLOW)install-no-cron$(NC)  - Установка без cron"
	@echo "  $(YELLOW)verify$(NC)           - Проверка установки"
	@echo "  $(YELLOW)monitor$(NC)          - Мониторинг состояния"
	@echo "  $(YELLOW)clean$(NC)            - Очистка временных файлов"
	@echo "  $(YELLOW)test$(NC)             - Тестирование всех скриптов"
	@echo ""
	@echo "$(GREEN)Запуск скриптов:$(NC)"
	@echo "  $(YELLOW)backup$(NC)           - Запуск бэкапа"
	@echo "  $(YELLOW)logs$(NC)             - Ротация логов"
	@echo "  $(YELLOW)deploy$(NC)           - Показать справку по деплою"
	@echo "  $(YELLOW)healthcheck$(NC)      - Проверка состояния"
	@echo ""
	@echo "$(GREEN)Примеры:$(NC)"
	@echo "  make install"
	@echo "  make monitor"
	@echo "  make backup"

# Установка
install:
	@echo "$(BLUE)[STEP]$(NC) Установка dotfiles-or-scripts..."
	@chmod +x install.sh
	@./install.sh

install-no-cron:
	@echo "$(BLUE)[STEP]$(NC) Установка без cron..."
	@chmod +x install.sh
	@./install.sh --no-cron

# Проверка установки
verify:
	@echo "$(BLUE)[STEP]$(NC) Проверка установки..."
	@chmod +x install.sh
	@./install.sh --verify

# Мониторинг
monitor:
	@echo "$(BLUE)[STEP]$(NC) Запуск мониторинга..."
	@chmod +x $(SCRIPTS_DIR)/utils/monitor.sh
	@$(SCRIPTS_DIR)/utils/monitor.sh

# Очистка
clean:
	@echo "$(BLUE)[STEP]$(NC) Очистка временных файлов..."
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@find . -name "*~" -delete
	@echo "$(GREEN)✓ Очистка завершена$(NC)"

# Тестирование
test:
	@echo "$(BLUE)[STEP]$(NC) Тестирование скриптов..."
	@echo "$(YELLOW)Проверка синтаксиса...$(NC)"
	@bash -n $(SCRIPTS_DIR)/backup/backup.sh
	@bash -n $(SCRIPTS_DIR)/logs/rotate.sh
	@bash -n $(SCRIPTS_DIR)/deploy/deploy.sh
	@bash -n $(SCRIPTS_DIR)/healthcheck/check.sh
	@bash -n $(SCRIPTS_DIR)/utils/monitor.sh
	@echo "$(GREEN)✓ Синтаксис всех скриптов корректен$(NC)"
	@echo "$(YELLOW)Проверка прав доступа...$(NC)"
	@ls -la $(SCRIPTS_DIR)/*/*.sh
	@echo "$(GREEN)✓ Тестирование завершено$(NC)"

# Запуск скриптов
backup:
	@echo "$(BLUE)[STEP]$(NC) Запуск бэкапа..."
	@echo "$(YELLOW)Внимание: запуск с правами sudo$(NC)"
	@sudo $(SCRIPTS_DIR)/backup/backup.sh

logs:
	@echo "$(BLUE)[STEP]$(NC) Ротация логов..."
	@echo "$(YELLOW)Внимание: запуск с правами sudo$(NC)"
	@sudo $(SCRIPTS_DIR)/logs/rotate.sh

deploy:
	@echo "$(BLUE)[STEP]$(NC) Справка по деплою..."
	@echo "$(YELLOW)Использование:$(NC)"
	@echo "  sudo $(SCRIPTS_DIR)/deploy/deploy.sh <путь_к_файлам>"
	@echo ""
	@echo "$(YELLOW)Примеры:$(NC)"
	@echo "  sudo $(SCRIPTS_DIR)/deploy/deploy.sh /path/to/app/"
	@echo "  sudo $(SCRIPTS_DIR)/deploy/deploy.sh /path/to/app.tar.gz"

healthcheck:
	@echo "$(BLUE)[STEP]$(NC) Проверка состояния..."
	@echo "$(YELLOW)Внимание: запуск с правами sudo$(NC)"
	@sudo $(SCRIPTS_DIR)/healthcheck/check.sh

# Создание архивов
package:
	@echo "$(BLUE)[STEP]$(NC) Создание архива проекта..."
	@tar -czf dotfiles-or-scripts-$(shell date +%Y%m%d).tar.gz \
		--exclude='*.log' \
		--exclude='*.tmp' \
		--exclude='*.tar.gz' \
		--exclude='.git' \
		.
	@echo "$(GREEN)✓ Архив создан$(NC)"

# Установка прав доступа
permissions:
	@echo "$(BLUE)[STEP]$(NC) Установка прав доступа..."
	@chmod +x install.sh
	@chmod +x $(SCRIPTS_DIR)/*/*.sh
	@chmod +x $(SCRIPTS_DIR)/utils/*.sh
	@echo "$(GREEN)✓ Права доступа установлены$(NC)"

# Показ структуры проекта
tree:
	@echo "$(BLUE)[STEP]$(NC) Структура проекта:"
	@tree -I '*.log|*.tmp|*.tar.gz|.git' -a

# Статус проекта
status:
	@echo "$(BLUE)[STEP]$(NC) Статус проекта:"
	@echo "$(YELLOW)Скрипты:$(NC)"
	@ls -la $(SCRIPTS_DIR)/*/*.sh
	@echo "$(YELLOW)Конфигурация:$(NC)"
	@ls -la $(CONFIG_DIR)/
	@echo "$(YELLOW)Логи:$(NC)"
	@ls -la $(LOGS_DIR)/ 2>/dev/null || echo "Директория логов не создана"

# Обновление из git
update:
	@echo "$(BLUE)[STEP]$(NC) Обновление из git..."
	@git pull origin main
	@make permissions
	@echo "$(GREEN)✓ Проект обновлен$(NC)" 