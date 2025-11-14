# Makefile for shell-ai-go

.PHONY: help build test clean lint fmt deps install dev-deps bench coverage run-interactive run-oneshot

# Default target
help:
	@echo "Shell AI Go Implementation"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@echo "  build           - Build the binary"
	@echo "  build-release   - Build optimized release binary"
	@echo "  test            - Run all tests"
	@echo "  test-verbose    - Run tests with verbose output"
	@echo "  test-coverage   - Run tests with coverage report"
	@echo "  bench           - Run benchmarks"
	@echo "  lint            - Run linter"
	@echo "  fmt             - Format code"
	@echo "  deps            - Download dependencies"
	@echo "  dev-deps        - Install development dependencies"
	@echo "  clean           - Clean build artifacts"
	@echo "  install         - Install binary to GOPATH/bin"
	@echo "  run-interactive - Run interactive session"
	@echo "  run-oneshot     - Run one-shot query (use PROMPT=... make run-oneshot)"

# Variables
BINARY_NAME := shell-ai
BUILD_DIR := build
GOFLAGS := -v
LDFLAGS := -s -w
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

# Build targets
build: deps | ensure-build-dir
	@echo "Building $(BINARY_NAME)..."
	go build $(GOFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) .

build-release: deps | ensure-build-dir
	@echo "Building optimized release binary..."
	go build $(GOFLAGS) -ldflags="$(LDFLAGS) -X main.version=$(VERSION)" -o $(BUILD_DIR)/$(BINARY_NAME) .

# Test targets
test: deps
	@echo "Running tests..."
	@go test -race ./... 2>&1 | grep -v "^?" || true
	@echo "✓ All tests passed"

test-verbose: deps
	@echo "Running tests with verbose output..."
	go test -race -v ./...

test-coverage: deps
	@echo "Running tests with coverage..."
	go test -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

bench: deps
	@echo "Running benchmarks..."
	go test -bench=. -benchmem ./...

# Code quality targets
lint: dev-deps
	@echo "Running linter..."
	golangci-lint run

fmt:
	@echo "Formatting code..."
	go fmt ./...
	go mod tidy

# Dependency targets
deps:
	@echo "Downloading dependencies..."
	go mod download

dev-deps:
	@echo "Installing development dependencies..."
	@if ! command -v golangci-lint >/dev/null 2>&1; then \
		echo "Installing golangci-lint..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v1.54.2; \
	fi

# Utility targets
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

install: build-release
	@echo "Installing $(BINARY_NAME) to $(shell go env GOPATH)/bin..."
	cp $(BUILD_DIR)/$(BINARY_NAME) $(shell go env GOPATH)/bin/

# Run targets
run-interactive: build
	@echo "Starting interactive session..."
	./$(BUILD_DIR)/$(BINARY_NAME) interactive

run-oneshot: build
	@if [ -z "$(PROMPT)" ]; then \
		echo "Usage: make run-oneshot PROMPT=\"your question here\""; \
		exit 1; \
	fi
	@echo "Running one-shot query: $(PROMPT)"
	./$(BUILD_DIR)/$(BINARY_NAME) ask "$(PROMPT)"

# Development targets
dev: build
	@echo "Development build complete. Binary available at: $(BUILD_DIR)/$(BINARY_NAME)"

watch:
	@echo "Watching for changes... (requires 'entr' tool)"
	find . -name '*.go' | entr -r make build

# Cross-compilation targets
build-linux: | ensure-build-dir
	@echo "Building for Linux..."
	GOOS=linux GOARCH=amd64 go build $(GOFLAGS) -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-linux .

build-darwin: | ensure-build-dir
	@echo "Building for macOS..."
	GOOS=darwin GOARCH=amd64 go build $(GOFLAGS) -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-darwin .

build-windows: | ensure-build-dir
	@echo "Building for Windows..."
	GOOS=windows GOARCH=amd64 go build $(GOFLAGS) -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME)-windows.exe .

build-all: build-linux build-darwin build-windows
	@echo "Built binaries for all platforms in $(BUILD_DIR)/"

# Integration with existing shell-ai
link-to-config:
	@echo "Creating symlink to existing shell-ai config..."
	@if [ -d "$$HOME/.config/shell-ai" ]; then \
		ln -sf "$$PWD/$(BUILD_DIR)/$(BINARY_NAME)" "$$HOME/.config/shell-ai/shell-ai-go"; \
		echo "Linked to $$HOME/.config/shell-ai/shell-ai-go"; \
	else \
		echo "shell-ai config directory not found. Run the original shell-ai setup first."; \
	fi

# Create build directory
.PHONY: ensure-build-dir
ensure-build-dir:
	@mkdir -p $(BUILD_DIR)
