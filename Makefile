# Front door. The work lives in scripts/ and in each half's own Makefile.
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

.PHONY: help dev check test lint build fmt

help: ## Show the available targets
	@printf "$(GREEN)$(notdir $(CURDIR))$(NC)\n\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-z-]+:.*##/ {printf "  $(YELLOW)%-8s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## api + web, one command
	@scripts/dev.sh

check: ## the gate: vet, tests -race, lint, build, conventions, ports
	@scripts/preflight.sh

test: ## tests and lint only (no vite build)
	@scripts/preflight.sh --fast

lint: ## golangci-lint + eslint/prettier
	@cd server && $(MAKE) lint
	@cd web && npm run lint --silent

build: ## both halves
	@cd server && $(MAKE) build
	@cd web && npm run build

fmt: ## gofmt + prettier --write
	@cd server && $(MAKE) fmt
	@cd web && npm run format
