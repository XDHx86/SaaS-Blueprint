# =============================================================================
# Infrastructure Lab — Developer UX
# =============================================================================
# One-command entrypoints for the common operations. Run `make help` for the
# full list. Compose files live under ./compose and are referenced explicitly,
# so `docker compose ...` issued directly at the root will NOT find the project
# — go through Make, or set the -f flags yourself.
# =============================================================================

.DEFAULT_GOAL := help
SHELL        := /usr/bin/env bash

COMPOSE      ?= docker compose

# The base node-exporter bind-mounts the host rootfs with `rslave` propagation,
# which Docker Desktop on Windows does not support.
# compose/docker-compose.windows.yml swaps it for a plain `ro` bind. Include it
# automatically on Windows only: OS=Windows_NT is set by Windows' environment
# and inherited even under Git Bash; on Linux/macOS $(OS) is unset, so
# PLATFORM_FILES is empty and the resulting -f list is identical to before.
ifeq ($(OS),Windows_NT)
PLATFORM_FILES := -f compose/docker-compose.windows.yml
else
PLATFORM_FILES :=
endif

DEV_FILES    := -f compose/docker-compose.yml -f compose/docker-compose.override.yml $(PLATFORM_FILES)
PROD_FILES   := -f compose/docker-compose.yml -f compose/docker-compose.prod.yml $(PLATFORM_FILES)
ENV          ?= .env

# --- Help --------------------------------------------------------------------
.PHONY: help
help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} \
	/^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# --- Bootstrap ---------------------------------------------------------------
.PHONY: bootstrap
bootstrap: ## Generate strong secrets into .env + preflight checks
	@bash scripts/bootstrap.sh

# --- Lifecycle (dev) ---------------------------------------------------------
.PHONY: up
up: ## Build and start the dev stack (base + local override)
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) up -d --build

.PHONY: down
down: ## Stop and remove dev containers
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) down

.PHONY: restart
restart: down up ## Restart the dev stack

.PHONY: logs
logs: ## Tail logs (Ctrl-C to exit)
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) logs -f --tail=200

.PHONY: ps
ps: ## Show service status (expect `(healthy)`)
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) ps

.PHONY: shell
shell: ## Shell into the backend container
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) exec backend sh || $(COMPOSE) --env-file $(ENV) $(DEV_FILES) run --rm backend sh

# --- Quality -----------------------------------------------------------------
.PHONY: lint
lint: ## Lint shell scripts and validate compose configs
	@bash scripts/lint.sh

.PHONY: test
test: ## Run the backend test suite in a throwaway container
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) run --rm backend npm test

# --- Operations --------------------------------------------------------------
.PHONY: backup
backup: ## Dump Postgres into ./backups (timestamped)
	@bash scripts/backup.sh

.PHONY: restore
restore: ## Restore a backup: make restore FILE=backups/<file>.sql.gz
	@test -n "$(FILE)" || { echo "Usage: make restore FILE=backups/<file>.sql.gz"; exit 1; }
	@bash scripts/restore.sh "$(FILE)"

.PHONY: health
health: ## Run the composite healthcheck against the stack
	@bash scripts/healthcheck.sh http://localhost

# --- Production overlay -------------------------------------------------------
.PHONY: prod-up
prod-up: ## Bring up the hardened production overlay (replicas honored via --compatibility)
	$(COMPOSE) --env-file $(ENV) --compatibility --env-file $(ENV) $(PROD_FILES) up -d

.PHONY: prod-config
prod-config: ## Render the fully-resolved production compose config (replicas honored via --compatibility)
	$(COMPOSE) --env-file $(ENV) --compatibility --env-file $(ENV) $(PROD_FILES) config

# --- Teardown -----------------------------------------------------------------
.PHONY: clean
clean: ## Remove containers/networks (keeps named volumes/data)
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) down --remove-orphans

.PHONY: nuke
nuke: ## DESTRUCTIVE: remove containers, networks, AND named volumes
	$(COMPOSE) --env-file $(ENV) $(DEV_FILES) down -v --remove-orphans
