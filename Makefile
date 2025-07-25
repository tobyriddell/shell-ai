# Shell AI Integration - Makefile
# Build and manage Docker images for bash and zsh environments

# Image names and tags
BASH_IMAGE := shell-ai-bash
ZSH_IMAGE := shell-ai-zsh
TAG := latest

# Docker build context
BUILD_CONTEXT := .

# Source file dependencies
SCRIPTS := $(wildcard scripts/*.sh) install.sh
CONFIG := $(wildcard config/*.sh config/*.json config/tmux.conf)
PROVIDERS := $(wildcard providers/*.sh)
RUST_SOURCES := tmux-selector/src/main.rs tmux-selector/Cargo.toml
RUST_BINARY := tmux-selector/target/release/tmux-selector
TEST_SCRIPTS := $(wildcard tests/*.sh)
COMMON_DEPS := $(SCRIPTS) $(CONFIG) $(PROVIDERS) $(RUST_BINARY) $(TEST_SCRIPTS)


# Build stamp files
BASH_STAMP := .bash-image-$(TAG).stamp
ZSH_STAMP := .zsh-image-$(TAG).stamp
RUST_STAMP := .rust-binary-$(TAG).stamp

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Shell AI Integration - Docker Build Targets"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: all
all: rust-binary bash zsh ## Build Rust binary and both bash and zsh images

.PHONY: force-bash force-zsh force-rust force-all
force-bash: ## Force rebuild bash image (ignore dependencies)
	@rm -f $(BASH_STAMP)
	@$(MAKE) bash

force-zsh: ## Force rebuild zsh image (ignore dependencies) 
	@rm -f $(ZSH_STAMP)
	@$(MAKE) zsh

force-rust: ## Force rebuild Rust binary (ignore dependencies)
	@rm -f $(RUST_STAMP)
	@$(MAKE) rust-binary

force-all: ## Force rebuild Rust binary and both images (ignore dependencies)
	@rm -f $(BASH_STAMP) $(ZSH_STAMP) $(RUST_STAMP)
	@$(MAKE) all

# Build Rust binary for tmux pane selection
rust-binary: $(RUST_STAMP) ## Build Rust tmux-selector binary
$(RUST_STAMP): $(RUST_SOURCES)
	@echo "Building Rust tmux-selector binary..."
	@if ! command -v cargo >/dev/null 2>&1; then \
		echo "Error: Rust/Cargo not found. Please install Rust: https://rustup.rs/"; \
		exit 1; \
	fi
	cd tmux-selector && cargo build --release
	@echo "✓ Built tmux-selector binary"
	@touch $(RUST_STAMP)

# Build bash Docker image only when dependencies change
bash: $(BASH_STAMP) ## Build bash Docker image
$(BASH_STAMP): Dockerfile.bash $(COMMON_DEPS)
	@echo "Building bash Docker image..."
	docker build -f Dockerfile.bash -t $(BASH_IMAGE):$(TAG) $(BUILD_CONTEXT)
	@echo "✓ Built $(BASH_IMAGE):$(TAG)"
	@touch $(BASH_STAMP)

# Build zsh Docker image only when dependencies change  
zsh: $(ZSH_STAMP) ## Build zsh Docker image
$(ZSH_STAMP): Dockerfile.zsh $(COMMON_DEPS)
	@echo "Building zsh Docker image..."
	docker build -f Dockerfile.zsh -t $(ZSH_IMAGE):$(TAG) $(BUILD_CONTEXT)
	@echo "✓ Built $(ZSH_IMAGE):$(TAG)"
	@touch $(ZSH_STAMP)

.PHONY: run-bash
run-bash: bash ## Build and run bash container interactively
	@echo "Starting bash container..."
	docker run -it --rm $(BASH_IMAGE):$(TAG)

.PHONY: run-zsh
run-zsh: zsh ## Build and run zsh container interactively
	@echo "Starting zsh container..."
	docker run -it --rm $(ZSH_IMAGE):$(TAG)

.PHONY: run-bash-config
run-bash-config: bash ## Run bash container with mounted config
	@echo "Starting bash container with config..."
	docker run -it --rm \
		-v $(PWD)/config/ai-config.example.json:/home/shelluser/.config/shell-ai/config.json:ro \
		$(BASH_IMAGE):$(TAG)

.PHONY: run-zsh-config
run-zsh-config: zsh ## Run zsh container with mounted config
	@echo "Starting zsh container with config..."
	docker run -it --rm \
		-v $(PWD)/config/ai-config.example.json:/home/shelluser/.config/shell-ai/config.json:ro \
		$(ZSH_IMAGE):$(TAG)

.PHONY: test-bash
test-bash: bash ## Build bash image and run tests
	@echo "Running tests in bash container..."
	docker run --rm $(BASH_IMAGE):$(TAG) ./tests/test_runner.sh bash

.PHONY: test-zsh
test-zsh: zsh ## Build zsh image and run tests
	@echo "Running tests in zsh container..."
	docker run --rm $(ZSH_IMAGE):$(TAG) ./tests/test_runner.sh zsh

.PHONY: test-install
test-install: bash ## Build bash image and run installation tests
	@echo "Running installation tests in bash container..."
	docker run --rm $(BASH_IMAGE):$(TAG) ./tests/test_runner.sh install

.PHONY: test-install-debug
test-install-debug: bash ## Build bash image and run installation tests with debug output
	@echo "Running installation tests in bash container (debug mode)..."
	docker run --rm $(BASH_IMAGE):$(TAG) ./tests/test_runner.sh install debug

.PHONY: test
test: test-bash test-zsh test-install ## Run all tests (bash, zsh, and installation)

.PHONY: shell-bash
shell-bash: bash ## Open bash shell in container for debugging
	@echo "Opening bash shell in container..."
	docker run -it --rm --entrypoint=/bin/bash $(BASH_IMAGE):$(TAG)

.PHONY: shell-zsh
shell-zsh: zsh ## Open zsh shell in container for debugging
	@echo "Opening zsh shell in container..."
	docker run -it --rm --entrypoint=/bin/zsh $(ZSH_IMAGE):$(TAG)

.PHONY: dev-bash
dev-bash: bash ## Run bash container with project mounted for development
	@echo "Starting bash development container..."
	docker run -it --rm \
		-v $(PWD):/workspace \
		-v $(PWD)/config/ai-config.example.json:/home/shelluser/.config/shell-ai/config.json:ro \
		-w /workspace \
		$(BASH_IMAGE):$(TAG)

.PHONY: dev-zsh
dev-zsh: zsh ## Run zsh container with project mounted for development
	@echo "Starting zsh development container..."
	docker run -it --rm \
		-v $(PWD):/workspace \
		-v $(PWD)/config/ai-config.example.json:/home/shelluser/.config/shell-ai/config.json:ro \
		-w /workspace \
		$(ZSH_IMAGE):$(TAG)

.PHONY: clean
clean: ## Remove built Docker images, Rust binary, and build stamps
	@echo "Removing Docker images, Rust binary, and build stamps..."
	-docker rmi $(BASH_IMAGE):$(TAG) 2>/dev/null || true
	-docker rmi $(ZSH_IMAGE):$(TAG) 2>/dev/null || true
	-rm -f $(BASH_STAMP) $(ZSH_STAMP) $(RUST_STAMP)
	-cd tmux-selector && cargo clean 2>/dev/null || true
	@echo "✓ Cleaned up images, binary, and build stamps"

.PHONY: check
check: ## Check if Dockerfiles and dependencies exist
	@echo "Checking dependencies..."
	@test -f Dockerfile.bash && echo "✓ Dockerfile.bash exists" || echo "✗ Dockerfile.bash missing"
	@test -f Dockerfile.zsh && echo "✓ Dockerfile.zsh exists" || echo "✗ Dockerfile.zsh missing"
	@test -d scripts && echo "✓ scripts/ directory exists" || echo "✗ scripts/ directory missing"
	@test -d config && echo "✓ config/ directory exists" || echo "✗ config/ directory missing"
	@test -d tmux-selector && echo "✓ tmux-selector/ directory exists" || echo "✗ tmux-selector/ directory missing"
	@command -v cargo >/dev/null 2>&1 && echo "✓ Rust/Cargo available" || echo "✗ Rust/Cargo not found"

# Build targets for CI/CD
.PHONY: build-bash-ci
build-bash-ci: ## Build bash image for CI (no cache)
	docker build --no-cache -f Dockerfile.bash -t $(BASH_IMAGE):$(TAG) $(BUILD_CONTEXT)

.PHONY: build-zsh-ci
build-zsh-ci: ## Build zsh image for CI (no cache)
	docker build --no-cache -f Dockerfile.zsh -t $(ZSH_IMAGE):$(TAG) $(BUILD_CONTEXT)

.PHONY: ci
ci: build-bash-ci build-zsh-ci test ## Full CI build and test pipeline 