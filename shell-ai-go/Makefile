# Makefile for shell-ai-go

.PHONY: help build test clean deps install

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
