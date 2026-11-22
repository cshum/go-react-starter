GO ?= go

.PHONY: run build test tidy fmt vet lint

run:
	$(GO) run ./cmd/app serve

build:
	$(GO) build -trimpath -o bin/app ./cmd/app

test:
	$(GO) test -race ./...

tidy:
	$(GO) mod tidy

fmt:
	gofmt -w .

vet:
	$(GO) vet ./...

lint:
	golangci-lint run ./...
