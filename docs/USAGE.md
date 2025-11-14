# Shell AI Integration - Detailed Usage Guide

> **🚀 PRIMARY**: This guide covers the **Go implementation** (recommended).  
> **⚠️ LEGACY**: For the deprecated bash implementation, see [Legacy Bash Implementation](#legacy-bash-implementation-deprecated) section below.

This guide provides comprehensive documentation for using the Shell AI Integration system.

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Basic Usage](#basic-usage)
4. [Advanced Features](#advanced-features)
5. [tmux Integration](#tmux-integration)
6. [Troubleshooting](#troubleshooting)
7. [API Reference](#api-reference)

## Installation

### Go Implementation (Recommended)

```bash
# Clone and install
git clone <repository-url>
cd shell-ai
make install

# Configure AI providers
shell-ai setup

# Reload shell (bash or zsh)
source ~/.bashrc  # or source ~/.zshrc

# Reload tmux configuration
tmux source-file ~/.tmux.conf
```

The installation process will:
1. Build the Go binary
2. Install `shell-ai` to `~/.local/bin/`
3. Copy tmux configuration to `~/.tmux.conf`
4. Set up shell aliases in `~/.bashrc` or `~/.zshrc`

### Docker (Development)

```bash
# Build and run
make run-bash    # or make run-zsh
make dev-bash    # Development with project mounted
```

## Configuration

### Interactive Setup

```bash
# Interactive configuration wizard
shell-ai setup
```

This will guide you through:
1. Selecting AI providers to enable
2. Entering API keys securely
3. Configuring model preferences
4. Setting up context and conversation settings

### Configuration File

The Go implementation uses YAML format (`~/.config/shell-ai/config.yaml`):

```yaml
providers:
  openai:
    enabled: true
    api_key: "sk-..."
    model: "gpt-4"
    max_tokens: 2000
    temperature: 0.7
  
  anthropic:
    enabled: false
    api_key: "sk-ant-..."
    model: "claude-3-sonnet-20240229"
    max_tokens: 2000
    temperature: 0.7

  google:
    enabled: false
    api_key: "AIza..."
    model: "gemini-1.5-flash"
    max_tokens: 2000
    temperature: 0.7

  ollama:
    enabled: false
    host: "http://localhost:11434"
    model: "llama2"
    max_tokens: 2000
    temperature: 0.7

settings:
  auto_copy: false
  auto_copy_prompt: true
  max_history_lines: 50
  max_pane_lines: 100
  conversation_ttl_hours: 24
```

### Secure Configuration

```bash
# Secure config file
chmod 600 ~/.config/shell-ai/config.yaml
```

## Basic Usage

### Interactive Sessions (Recommended)

```bash
# Start interactive session
shell-ai interactive

# Or use the alias
ai-interactive
```

In interactive mode:
- Type your questions naturally
- Use `/send` to send commands to tmux panes
- Use `/context` to view current context
- Use `/clear` to clear conversation history
- Use `/help` for available commands
- Press `Ctrl-D` to exit

### One-shot Queries

```bash
# Basic query
shell-ai ask "how do I find large files?"

# Or use the alias
ai "how do I find large files?"

# @ prefix still works (via shell integration)
@what does ps aux do

# Specify provider
shell-ai ask --provider openai "explain this error"

# Context control
shell-ai ask --no-history "query"   # Exclude shell history
shell-ai ask --no-panes "query"      # Exclude tmux content
shell-ai ask -c 20 "query"           # Limit context lines
```

### Helper Functions

```bash
# Explain last command
ai-last

# Ask about current directory
ai-here "what are these files for?"

# Fix last failed command
ai-fix
```

### Testing Providers

```bash
# Test all providers
shell-ai test

# Or use the alias
ai-test
```

## Advanced Features

### Response Management

In interactive mode, use the `/send` command to send AI-generated commands to tmux panes:
```bash
shell-ai interactive
🤖 AI> How do I find large files?
# AI responds with: find . -type f -size +100M
🤖 AI> /send
# Select target pane, then confirm execution
```

### Context Management

The AI automatically receives:
- System information
- Shell history (via atuin if available)
- Current tmux pane content
- Working directory and file listings
- Previous conversation context

```bash
# Example workflow
cd /var/log
ls -la
tail -f syslog
# Ctrl-C to stop
shell-ai ask "analyze these log files for errors"
```

### Conversation Context

The Go implementation maintains conversation context across multiple queries:
- Context is automatically included in follow-up questions
- Context expires after 24 hours (configurable)
- Use `/clear` in interactive mode to reset context

## tmux Integration

### Keybindings

All keybindings use the Ctrl-A prefix:

| Keybinding | Action |
|------------|--------|
| `Ctrl-A + S` | Start interactive AI session |
| `Ctrl-A + I` | Quick AI query with prompt |
| `Ctrl-A + Q` | One-shot AI query |
| `Ctrl-A + T` | Test AI providers |
| `Ctrl-A + E` | Explain current pane output |
| `Ctrl-A + X` | Show AI context |
| `Ctrl-A + C` | AI copy manager (interactive mode) |

### Built-in Pane Selection

The Go implementation includes built-in tmux pane selection:
- Automatically detects when you're in a tmux session
- Visual pane selector with arrow key navigation
- Safe command execution with confirmation prompts
- Context includes all visible pane content

### Interactive Session Workflow

1. **Start session**: Press `Ctrl-A + S` or run `shell-ai interactive`
2. **Ask questions**: Type naturally in the interactive prompt
3. **Send commands**: Use `/send` to send commands to selected panes
4. **Review context**: Use `/context` to see what context is being sent
5. **Exit**: Press `Ctrl-D` to exit

### tmux Configuration

The installation automatically configures `~/.tmux.conf` with:
- Ctrl-A prefix (instead of Ctrl-B)
- Vi-mode keys for buffer searching
- AI integration keybindings
- Enhanced pane navigation

## Troubleshooting

### Common Issues

```bash
# Commands not found
source ~/.bashrc  # or ~/.zshrc
# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# AI not responding
shell-ai test
shell-ai setup

# tmux issues
tmux source-file ~/.tmux.conf

# Check configuration
cat ~/.config/shell-ai/config.yaml

# Rebuild if needed
cd shell-ai-go && make clean && make build
```

### Debug Mode

```bash
# Test with minimal context
shell-ai ask --no-history --no-panes "test"

# Check if binary is accessible
which shell-ai
shell-ai --help
```

### zsh Globbing Issues

**Problem**: In zsh, special characters like `?` and `*` in prompts can cause globbing errors:
```bash
ai What is the speed of light?
# Error: zsh: no matches found: light?
```

**Solutions** (choose one):

#### Option 1: Quote Your Prompts (Immediate Fix)
Always quote prompts containing special characters:
```bash
ai "What is the speed of light?"
ai 'How do I use wildcards like * and ?'
```

#### Option 2: Configure zsh to Handle Unmatched Patterns (Recommended)
Add this line to your `~/.zshrc` or to `~/.config/shell-ai/zshrc-ai.sh`:
```bash
# Prevent zsh from failing on unmatched glob patterns
setopt nonomatch
```

This makes zsh treat unmatched glob patterns as literal strings (similar to bash behavior).

#### Option 3: Alternative zsh Options
Other zsh configuration options:
```bash
setopt nullglob     # Unmatched patterns expand to nothing
setopt noglobsubst  # Disable glob expansion in substitution
```

#### Option 4: Use Alternative Input Methods
```bash
# Pipe input to avoid globbing
echo "What is the speed of light?" | ai

# Use here-string
ai <<< "What is the speed of light?"
```

**Recommendation**: Use Option 2 (`setopt nonomatch`) for the best user experience, as it automatically handles the issue without requiring users to change their input habits.

## Creating Custom Providers

You can create custom AI providers by creating new files in the `providers/` directory.

### Provider Template

Create `~/.config/shell-ai/providers/custom.sh`:

```bash
#!/bin/bash
# Custom AI Provider

# Provider metadata
PROVIDER_NAME="Custom"
PROVIDER_DESCRIPTION="Custom AI Provider"

# API call function
call_custom() {
    local provider_config="$1"
    local prompt="$2"
    
    # Extract parameters from config
    local api_key model endpoint
    api_key=$(echo "$provider_config" | jq -r '.api_key')
    model=$(echo "$provider_config" | jq -r '.model')
    endpoint=$(echo "$provider_config" | jq -r '.endpoint // "https://api.example.com/v1/chat"')
    
    # Implement your API call here
    curl -s -X POST "$endpoint" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": $(echo "$prompt" | jq -R -s .),
            \"max_tokens\": 2000
        }" | jq -r '.response // .error // "Error: Invalid response"'
}

# Setup function
setup_custom() {
    echo -e "${GREEN}Setting up Custom Provider...${NC}"
    read -p "Enable Custom provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        jq '.providers.custom = (.providers.custom // {}) | .providers.custom.enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}Custom provider disabled.${NC}"
    else
        read -p "Enter API key: " -s api_key
        echo
        read -p "Enter model: " model
        read -p "Enter endpoint (optional): " endpoint
        
        if [[ -n "$endpoint" ]]; then
            jq --arg key "$api_key" --arg model "$model" --arg endpoint "$endpoint" \
               '.providers.custom = {"api_key": $key, "model": $model, "endpoint": $endpoint, "enabled": true}' \
               "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        else
            jq --arg key "$api_key" --arg model "$model" \
               '.providers.custom = {"api_key": $key, "model": $model, "enabled": true}' \
               "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        fi
        
        echo -e "${GREEN}Custom provider configured!${NC}"
    fi
}
```

### Required Functions

Every provider must implement:
- `call_<provider>(provider_config, prompt)`: Handle API calls with standardized interface
- `setup_<provider>()`: Handle configuration
- `PROVIDER_NAME` and `PROVIDER_DESCRIPTION` variables

**Provider Interface:**
- `provider_config`: JSON object containing all provider configuration
- `prompt`: The user's prompt/question
- Each provider extracts what it needs from the config (api_key, model, host, etc.)

### Environment-Specific Deployments

For different environments:
1. Include only the needed provider files
2. The system automatically adapts to available providers
3. No changes needed in main scripts

Example for a minimal environment:
```bash
# Only include custom provider
rm ~/.config/shell-ai/providers/openai.sh
rm ~/.config/shell-ai/providers/anthropic.sh
rm ~/.config/shell-ai/providers/google.sh
rm ~/.config/shell-ai/providers/ollama.sh
# Keep only custom.sh
```

## API Reference

### Go Implementation Commands

```bash
# Main commands
shell-ai interactive              # Start interactive session
shell-ai ask [PROMPT]             # Single question
shell-ai setup                     # Interactive configuration
shell-ai test                      # Test providers

# Aliases (automatically configured)
ai                                # Alias for shell-ai ask
ai-interactive                     # Alias for shell-ai interactive
ai-setup                          # Alias for shell-ai setup
ai-test                           # Alias for shell-ai test

# Helper functions
ai-last                           # Explain last command
ai-here [context]                 # Ask about current directory
ai-fix                            # Fix last failed command

# Key options
--provider [openai|anthropic|google|ollama]
--no-history                      # Exclude shell history
--no-panes                        # Exclude tmux content
-c, --context-lines N              # Limit context lines
```

### Interactive Mode Commands

When in `shell-ai interactive` mode:
- `/send` - Send last commands to tmux pane
- `/context` - Show current context
- `/clear` - Clear conversation history
- `/help` - Show help
- `Ctrl-D` - Exit

---

## Legacy Bash Implementation (Deprecated)

> **⚠️ DEPRECATED**: The bash implementation is no longer recommended.  
> **🚀 MIGRATE**: Use the Go implementation above for the best experience.

### Installation

```bash
git clone <repository-url>
cd shell-ai
chmod +x install.sh
./install.sh
```

### Usage

```bash
# @ prefix queries
@what does ps aux do

# Direct commands
ai "explain the ls command"
ai-setup
ai-copy
ai-test
```

### Configuration

Edit `~/.config/shell-ai/config.json` (JSON format, not YAML).

For more details on the legacy bash implementation, see the [Migration Guide](../README.md#-migration-from-bash-to-go).
``` 