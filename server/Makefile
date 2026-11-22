GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

.DEFAULT_GOAL := help

GO ?= go
# prefer a golangci-lint on PATH, fall back to the mise-pinned one
GOLANGCI ?= $(shell command -v golangci-lint >/dev/null 2>&1 && echo golangci-lint || echo "mise exec -- golangci-lint")

.PHONY: help run build test tidy fmt vet lint

help: ## Show the available targets
	@printf "$(GREEN)$(notdir $(CURDIR)) (go)$(NC)\n\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-z-]+:.*##/ {printf "  $(YELLOW)%-8s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

run: ## serve on :8080 (or -addr / ASSET_ADDR / PORT)
	$(GO) run ./cmd/app serve

build: ## build bin/app
	$(GO) build -trimpath -o bin/app ./cmd/app

test: ## go test -race ./...
	$(GO) test -race ./...

tidy: ## go mod tidy
	$(GO) mod tidy

fmt: ## gofmt -w .
	gofmt -w .

vet: ## go vet ./...
	$(GO) vet ./...

lint: ## golangci-lint run ./...
	$(GOLANGCI) run ./...
