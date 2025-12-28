# Shell AI Integration - Makefile
# Build and install the Go implementation

# Default target
.PHONY: help
help: ## Show this help message
	@echo "Shell AI Integration - Build and Installation"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: install
install: build ## Install shell-ai binary and configuration
	@echo "Installing Shell AI..."
	@mkdir -p ~/.local/bin
	@mkdir -p ~/.config/shell-ai
	@cp shell-ai-go/build/shell-ai ~/.local/bin/shell-ai
	@chmod +x ~/.local/bin/shell-ai
	@echo "✓ Installed shell-ai binary to ~/.local/bin/"
	@if [ -f scripts/install-tmux-config.sh ]; then \
		bash scripts/install-tmux-config.sh; \
	else \
		echo "⚠️  install-tmux-config.sh not found, using simple copy"; \
		if [ -f ~/.tmux.conf ]; then \
			echo "⚠️  ~/.tmux.conf already exists. Backing up to ~/.tmux.conf.backup"; \
			cp ~/.tmux.conf ~/.tmux.conf.backup; \
		fi; \
		cp config/tmux.conf ~/.tmux.conf; \
		echo "✓ Installed tmux configuration to ~/.tmux.conf"; \
	fi
	@echo ""
	@echo "Next steps:"
	@echo "1. Add ~/.local/bin to your PATH (if not already):"
	@echo "   echo 'export PATH=\$$HOME/.local/bin:\$$PATH' >> ~/.bashrc  # or ~/.zshrc"
	@echo "2. Reload your shell: source ~/.bashrc  # or source ~/.zshrc"
	@echo "3. Configure AI providers: shell-ai setup"
	@echo "4. Reload tmux config: tmux source-file ~/.tmux.conf"
	@echo ""
	@echo "✓ Installation complete!"

.PHONY: install-system
install-system: build ## Install shell-ai binary system-wide (requires sudo)
	@echo "Installing Shell AI system-wide..."
	@sudo cp shell-ai-go/build/shell-ai /usr/local/bin/shell-ai
	@sudo chmod +x /usr/local/bin/shell-ai
	@echo "✓ Installed shell-ai binary to /usr/local/bin/"
	@if [ -f scripts/install-tmux-config.sh ]; then \
		bash scripts/install-tmux-config.sh; \
	else \
		echo "⚠️  install-tmux-config.sh not found, using simple copy"; \
		if [ -f ~/.tmux.conf ]; then \
			echo "⚠️  ~/.tmux.conf already exists. Backing up to ~/.tmux.conf.backup"; \
			cp ~/.tmux.conf ~/.tmux.conf.backup; \
		fi; \
		cp config/tmux.conf ~/.tmux.conf; \
		echo "✓ Installed tmux configuration to ~/.tmux.conf"; \
	fi
	@echo ""
	@echo "Next steps:"
	@echo "1. Configure AI providers: shell-ai setup"
	@echo "2. Reload tmux config: tmux source-file ~/.tmux.conf"
	@echo ""
	@echo "✓ Installation complete!"

.PHONY: clean
clean: ## Clean build artifacts
	@$(MAKE) -C shell-ai-go clean
	@echo "✓ Cleaned up build artifacts"

.PHONY: check
check: ## Check if dependencies exist
	@echo "Checking dependencies..."
	@test -d shell-ai-go && echo "✓ shell-ai-go directory exists" || echo "✗ shell-ai-go directory missing"
	@test -d config && echo "✓ config/ directory exists" || echo "✗ config/ directory missing"
	@command -v go >/dev/null 2>&1 && echo "✓ Go available" || echo "✗ Go not found"

# Pattern rule: delegate any other target to shell-ai-go Makefile
# This catches: build, test, test-tmux, test-atuin, test-all, deps, build-release, build-debug, etc.
%:
	@$(MAKE) -C shell-ai-go $@
