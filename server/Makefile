GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

.DEFAULT_GOAL := help

GO ?= go
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
GOLANGCI ?= $(shell command -v golangci-lint >/dev/null 2>&1 && echo golangci-lint || echo "mise exec -- golangci-lint")

.PHONY: help run build test tidy fmt vet lint

help: ## Show the available targets
	@printf "$(GREEN)$(notdir $(CURDIR)) (go)$(NC)\n\n"
	@awk 'BEGIN {FS = ":.*##"} /^[a-z-]+:.*##/ {printf "  $(YELLOW)%-8s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

run: ## serve on :8080 (or -addr / APP_ADDR)
	$(GO) run ./cmd/app serve

build: ## build bin/app; embeds web/dist when the front end is present
	@if [ -d ../web ]; then npm --prefix ../web run build; else mkdir -p dist && touch dist/.keep; fi
	$(GO) build -tags embedui -trimpath -ldflags "-X main.version=$(VERSION)" -o bin/app ./cmd/app

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
