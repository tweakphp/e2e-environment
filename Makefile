# ==============================================================================
# TweakPHP E2E Testing Environment - Makefile
# ==============================================================================
.DEFAULT_GOAL := help
SHELL         := /bin/bash

# Detect docker compose implementation (V2 plugin vs V1 standalone)
DOCKER_COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)

# Colors for terminal output
BOLD   := \033[1m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RESET  := \033[0m

.PHONY: help up start down stop restart setup clean purge status ps logs info connections shell-docker shell-sail shell-ssh shell-k8s

## Show helper documentation
help:
	@printf "\n$(BOLD)$(YELLOW)==============================================================================$(RESET)\n"
	@printf " $(BOLD)🚀 TweakPHP E2E Testing Environment$(RESET)\n"
	@printf "$(BOLD)$(YELLOW)==============================================================================$(RESET)\n\n"
	@printf "$(BOLD)Usage:$(RESET) make [target]\n\n"
	@printf "$(BOLD)$(YELLOW)Environment Lifecycle:$(RESET)\n"
	@printf "  $(CYAN)%-18s$(RESET) Start environment (Docker & K8s) and show credentials\n" "up, start"
	@printf "  $(CYAN)%-18s$(RESET) Stop services safely (preserves apps/ for instant restart)\n" "down, stop"
	@printf "  $(CYAN)%-18s$(RESET) Restart running Docker containers\n" "restart"
	@printf "  $(CYAN)%-18s$(RESET) Build containers & provision Laravel apps from scratch\n" "setup"
	@printf "  $(CYAN)%-18s$(RESET) Full teardown: stop services and wipe apps/ directory\n" "clean, purge"
	@printf "\n"
	@printf "$(BOLD)$(YELLOW)Inspection & Logs:$(RESET)\n"
	@printf "  $(CYAN)%-18s$(RESET) Show status of Docker containers and Kubernetes pods\n" "status, ps"
	@printf "  $(CYAN)%-18s$(RESET) Display TweakPHP connection credentials & parameters\n" "info, connections"
	@printf "  $(CYAN)%-18s$(RESET) Follow Docker logs (optional filter: s=docker-laravel)\n" "logs"
	@printf "\n"
	@printf "$(BOLD)$(YELLOW)Interactive Shells:$(RESET)\n"
	@printf "  $(CYAN)%-18s$(RESET) Open bash shell inside tweakphp-docker-app\n" "shell-docker"
	@printf "  $(CYAN)%-18s$(RESET) Open bash shell inside tweakphp-sail-app\n" "shell-sail"
	@printf "  $(CYAN)%-18s$(RESET) Open bash shell inside tweakphp-ssh-app\n" "shell-ssh"
	@printf "  $(CYAN)%-18s$(RESET) Open bash shell inside Kubernetes Laravel pod\n" "shell-k8s"
	@printf "\n$(BOLD)$(YELLOW)==============================================================================$(RESET)\n\n"

# Lifecycle commands
up: start

start:
	@bash ./start.sh

down: stop

stop:
	@CLEAN_APPS=false bash ./stop.sh

restart:
	@echo "--> Restarting Docker Compose services..."
	@$(DOCKER_COMPOSE) restart
	@echo "--> Containers restarted."

setup:
	@bash ./setup.sh

clean: purge

purge:
	@CLEAN_APPS=true bash ./stop.sh

# Inspection commands
status: ps

ps:
	@echo "================ Docker Containers ================"
	@$(DOCKER_COMPOSE) ps
	@if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then \
		echo ""; \
		echo "================ Kubernetes Pods ==================="; \
		kubectl get pods -n tweakphp-test -o wide 2>/dev/null || echo "Namespace tweakphp-test not active"; \
	fi

logs:
	@$(DOCKER_COMPOSE) logs -f $(s)

info: connections

connections:
	@echo "============================================================"
	@echo " 📋 TWEAKPHP CONNECTION PARAMETERS"
	@echo "============================================================"
	@if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then \
		DOCKER_ID=$$(docker inspect -f '{{.Id}}' tweakphp-docker-app 2>/dev/null | cut -c1-12); \
		SAIL_ID=$$(docker inspect -f '{{.Id}}' tweakphp-sail-app 2>/dev/null | cut -c1-12); \
		SSH_ID=$$(docker inspect -f '{{.Id}}' tweakphp-ssh-app 2>/dev/null | cut -c1-12); \
		echo ""; \
		echo "🐳 [1] DOCKER CONNECTION"; \
		echo "------------------------------------------------------------"; \
		echo "  • Connection Type:   Docker"; \
		echo "  • Connection Name:   Docker E2E Test"; \
		echo "  • Container Name:    tweakphp-docker-app"; \
		echo "  • Container ID:      $${DOCKER_ID:-tweakphp-docker-app}"; \
		echo "  • Working Directory: /var/www/html"; \
		echo "  • PHP Path:          php"; \
		echo ""; \
		echo "⛵ [2] LARAVEL SAIL CONNECTION"; \
		echo "------------------------------------------------------------"; \
		echo "  • Connection Type:   Docker"; \
		echo "  • Connection Name:   Sail E2E Test"; \
		echo "  • Container Name:    tweakphp-sail-app"; \
		echo "  • Container ID:      $${SAIL_ID:-tweakphp-sail-app}"; \
		echo "  • Working Directory: /var/www/html"; \
		echo "  • PHP Path:          php"; \
		echo ""; \
		echo "🔑 [3] SSH CONNECTION"; \
		echo "------------------------------------------------------------"; \
		echo "  • Connection Type:   SSH"; \
		echo "  • Connection Name:   SSH E2E Test"; \
		echo "  • Host:              127.0.0.1 (or localhost)"; \
		echo "  • Port:              2222"; \
		echo "  • Username:          tweakphp"; \
		echo "  • Auth Type:         password"; \
		echo "  • Password:          secret123"; \
		echo "  • Path / WorkingDir: /var/www/html"; \
		echo "  • PHP Path:          php"; \
	else \
		echo "  [!] Docker is not running or not available."; \
	fi
	@if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then \
		K8S_POD=$$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
		[ -z "$$K8S_POD" ] && K8S_POD=$$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
		K8S_CONTEXT=$$(kubectl config current-context 2>/dev/null || echo "default"); \
		echo ""; \
		echo "☸️  [4] KUBERNETES (KUBECTL) CONNECTION"; \
		echo "------------------------------------------------------------"; \
		echo "  • Connection Type:   Kubectl"; \
		echo "  • Connection Name:   Kubernetes E2E Test"; \
		echo "  • Context:           $$K8S_CONTEXT"; \
		echo "  • Namespace:         tweakphp-test"; \
		echo "  • Pod Name:          $${K8S_POD:-tweakphp-k8s-laravel-xxxx}"; \
		echo "  • Path / WorkingDir: /var/www/html"; \
		echo "  • PHP Path:          php"; \
	fi
	@echo "============================================================"

# Shell access helpers
shell-docker:
	@docker exec -it tweakphp-docker-app bash

shell-sail:
	@docker exec -it tweakphp-sail-app bash

shell-ssh:
	@docker exec -it tweakphp-ssh-app bash

shell-k8s:
	@POD=$$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	[ -z "$$POD" ] && POD=$$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
		kubectl exec -it "$$POD" -n tweakphp-test -- bash; \
	else \
		echo "No running Kubernetes pod found in tweakphp-test namespace."; \
	fi
