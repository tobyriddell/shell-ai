# Shell AI Integration - Makefile
# Build and manage Docker images for bash and zsh environments

# Image names and tags
BASH_IMAGE := shell-ai-bash
ZSH_IMAGE := shell-ai-zsh
TAG := latest

# Docker build context
BUILD_CONTEXT := .

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
all: bash zsh ## Build both bash and zsh images

.PHONY: bash
bash: ## Build bash Docker image
	@echo "Building bash Docker image..."
	docker build -f Dockerfile.bash -t $(BASH_IMAGE):$(TAG) $(BUILD_CONTEXT)
	@echo "✓ Built $(BASH_IMAGE):$(TAG)"

.PHONY: zsh
zsh: ## Build zsh Docker image
	@echo "Building zsh Docker image..."
	docker build -f Dockerfile.zsh -t $(ZSH_IMAGE):$(TAG) $(BUILD_CONTEXT)
	@echo "✓ Built $(ZSH_IMAGE):$(TAG)"

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

.PHONY: test
test: test-bash test-zsh ## Run tests in both bash and zsh containers

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
clean: ## Remove built Docker images
	@echo "Removing Docker images..."
	-docker rmi $(BASH_IMAGE):$(TAG) 2>/dev/null || true
	-docker rmi $(ZSH_IMAGE):$(TAG) 2>/dev/null || true
	@echo "✓ Cleaned up images"

.PHONY: check
check: ## Check if Dockerfiles exist and are valid
	@echo "Checking Dockerfiles..."
	@test -f Dockerfile.bash && echo "✓ Dockerfile.bash exists" || echo "✗ Dockerfile.bash missing"
	@test -f Dockerfile.zsh && echo "✓ Dockerfile.zsh exists" || echo "✗ Dockerfile.zsh missing"
	@test -d scripts && echo "✓ scripts/ directory exists" || echo "✗ scripts/ directory missing"
	@test -d config && echo "✓ config/ directory exists" || echo "✗ config/ directory missing"

# Build targets for CI/CD
.PHONY: build-bash-ci
build-bash-ci: ## Build bash image for CI (no cache)
	docker build --no-cache -f Dockerfile.bash -t $(BASH_IMAGE):$(TAG) $(BUILD_CONTEXT)

.PHONY: build-zsh-ci
build-zsh-ci: ## Build zsh image for CI (no cache)
	docker build --no-cache -f Dockerfile.zsh -t $(ZSH_IMAGE):$(TAG) $(BUILD_CONTEXT)

.PHONY: ci
ci: build-bash-ci build-zsh-ci test ## Full CI build and test pipeline 