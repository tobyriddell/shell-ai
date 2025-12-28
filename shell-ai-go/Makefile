# Makefile for shell-ai-go

.PHONY: help build test test-tmux test-atuin test-integration test-all clean deps install

# Default target
help:
	@echo "Shell AI Go Implementation"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "Build targets:"
	@echo "  build           - Build the binary"
	@echo "  build-release   - Build optimized release binary"
	@echo "  build-debug     - Build debug binary (with debug logging enabled)"
	@echo ""
	@echo "Test targets:"
	@echo "  test            - Run all tests with verbose output"
	@echo "  test-tmux       - Run tmux integration tests (requires tmux)"
	@echo "  test-atuin      - Run atuin integration tests (requires atuin)"
	@echo "  test-integration - Run AI provider integration tests (requires API keys)"
	@echo "  test-all        - Run all tests including tmux, atuin, and integration tests"
	@echo ""
	@echo "Dependency targets:"
	@echo "  deps            - Download dependencies"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean           - Clean build artifacts"
	@echo "  install         - Install binary to GOPATH/bin"

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

build-debug: deps | ensure-build-dir
	@echo "Building debug binary (with debug logging enabled)..."
	go build $(GOFLAGS) -tags debug -o $(BUILD_DIR)/$(BINARY_NAME) .

# Test targets
test: deps
	@echo "Running tests with verbose output..."
	go test -race -v ./...

test-tmux: deps
	@echo "Checking for TMUX environment variable..."
	@test -n "$$TMUX" || (echo "✗ TMUX environment variable is not set. Please run tests inside a tmux session." && exit 1)
	@echo "✓ Running inside tmux session"
	@echo "Running tmux tests (including integration test)..."
	go test -race -v ./pkg/tmux/...

test-atuin: deps
	@echo "Checking for atuin..."
	@command -v atuin >/dev/null 2>&1 || (echo "✗ atuin is not available. Please install atuin to run atuin tests." && exit 1)
	@echo "✓ atuin is available"
	@echo "Running atuin integration tests..."
	go test -race -v ./pkg/contextgather/... -run TestGatherer_AtuinTmuxIntegration

test-integration: deps
	@echo "Running AI provider integration tests..."
	@echo "Checking for API keys..."
	@if [ -z "$$OPENAI_API_KEY" ] && [ -z "$$SHELL_AI_PROVIDERS_OPENAI_API_KEY" ] && \
	     [ -z "$$ANTHROPIC_API_KEY" ] && [ -z "$$SHELL_AI_PROVIDERS_ANTHROPIC_API_KEY" ] && \
	     [ -z "$$GOOGLE_API_KEY" ] && [ -z "$$GOOGLE_AI_API_KEY" ] && [ -z "$$SHELL_AI_PROVIDERS_GOOGLE_API_KEY" ] && \
	     ! command -v ollama >/dev/null 2>&1; then \
		echo "✗ No API keys found and Ollama is not available."; \
		echo ""; \
		echo "To run integration tests, set one of the following environment variables:"; \
		echo "  - OPENAI_API_KEY or SHELL_AI_PROVIDERS_OPENAI_API_KEY"; \
		echo "  - ANTHROPIC_API_KEY or SHELL_AI_PROVIDERS_ANTHROPIC_API_KEY"; \
		echo "  - GOOGLE_API_KEY, GOOGLE_AI_API_KEY, or SHELL_AI_PROVIDERS_GOOGLE_API_KEY"; \
		echo "  - Or ensure Ollama is installed and running (http://localhost:11434)"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ API key or Ollama detected"
	@echo ""
	go test -race -v ./pkg/ai/providers/... -run "Test.*_RealChat"

test-all: deps
	@echo "Running all tests including integration tests..."
	@$(MAKE) test
	@echo ""
	@echo "Running tmux integration tests..."
	@$(MAKE) test-tmux || echo "⚠️  tmux tests skipped or failed"
	@echo ""
	@echo "Running atuin integration tests..."
	@$(MAKE) test-atuin || echo "⚠️  atuin tests skipped or failed"
	@echo ""
	@echo "Running AI provider integration tests..."
	@$(MAKE) test-integration || echo "⚠️  integration tests skipped or failed"
	@echo ""
	@echo "✓ All tests completed"

# Dependency targets
deps:
	@echo "Downloading dependencies..."
	go mod download

# Utility targets
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

install: build-release
	@echo "Installing $(BINARY_NAME) to $(shell go env GOPATH)/bin..."
	cp $(BUILD_DIR)/$(BINARY_NAME) $(shell go env GOPATH)/bin/

# Create build directory
.PHONY: ensure-build-dir
ensure-build-dir:
	@mkdir -p $(BUILD_DIR)
