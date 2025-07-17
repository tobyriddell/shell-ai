# Shell AI Integration - Detailed Usage Guide

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

### Native Installation (Recommended)

```bash
git clone <repository-url>
cd shell-ai
chmod +x install.sh
./install.sh

# Reload shell (bash or zsh)
source ~/.bashrc
source ~/.zshrc
```

The installation process will:
1. Install main scripts to `~/.config/shell-ai/`
2. Install AI provider modules to `~/.config/shell-ai/providers/`
3. Set up shell integration (bashrc/zshrc)
4. Configure tmux integration (if tmux is available)

### Docker (Development)

```bash
# Build and run
make run-bash    # or make run-zsh
make dev-bash    # Development with project mounted
```

## Configuration

```bash
# Interactive setup
ai-setup

# Secure config file
chmod 600 ~/.config/shell-ai/config.json
```

### Modular Architecture

The shell-ai system uses a runtime provider loading architecture:

```
~/.config/shell-ai/
├── ai-shell.sh         # Main shell integration
├── ai-setup.sh         # Configuration script
├── providers/          # AI provider modules
│   ├── openai.sh
│   ├── anthropic.sh
│   ├── google.sh
│   └── ollama.sh
└── config.json         # Configuration file
```

**Key benefits:**
- **Environment-specific deployments**: Include only needed providers
- **No build step**: Providers are loaded at runtime
- **Easy customization**: Add custom providers by creating new files
- **Secure isolation**: Provider code can be kept separate per environment

Edit `~/.config/shell-ai/config.json`:
```json
{
  "providers": {
    "openai": {
      "api_key": "sk-proj-...",
      "model": "gpt-4",
      "enabled": true
    },
    "anthropic": {
      "api_key": "sk-ant-...",
      "model": "claude-3-sonnet-20240229",
      "enabled": false
    },
    "google": {
      "api_key": "AIza...",
      "model": "gemini-2.5-pro",
      "enabled": false
    },
    "ollama": {
      "host": "http://localhost:11434",
      "model": "llama2:7b",
      "enabled": false
    }
  }
}
```

## Basic Usage (bash/zsh)

```bash
# @ prefix queries
@what does ps aux do
@how to find files larger than 100MB
@fix this error: command not found
@write a script to backup my home directory

# Direct commands
ai "explain the ls command"
ai --provider anthropic "help debug this script"
ai-here "what are these files for?"
ai-last "explain this command"
ai-fix "fix the last failed command"

# Context control
ai --context              # Show context sent to AI
ai --no-history "query"   # Exclude shell history
ai --no-pane "query"      # Exclude tmux content
ai --history-lines 10 --pane-lines 20 "query"  # Limit context
```

## Advanced Features

**Response Management**: Use `ai-copy` for interactive menu to view, copy, and execute AI responses.

**Context**: AI receives system info, shell history (atuin), tmux content, and working directory.

```bash
# Example workflow
cd /var/log
ls -la
tail -f syslog
# Ctrl-C to stop
@analyze these log files for errors
```

## tmux Integration

### Keybindings

All keybindings use the Ctrl-A prefix:

| Keybinding | Action |
|------------|--------|
| `Ctrl-A + A` | Toggle AI input pane |
| `Ctrl-A + I` | Quick AI query prompt |
| `Ctrl-A + C` | AI response manager |
| `Ctrl-A + T` | Test AI providers |
| `Ctrl-A + X` | Show AI context |

### AI Input Pane Workflow

1. **Create pane**: Press `Ctrl-A + A`
2. **Query AI**: Type in the new pane: `ai "your question"`
3. **Review response**: Output appears in main pane
4. **Execute commands**: Use `ai-copy` to extract and run commands
5. **Close pane**: Type `exit` in AI pane

### Pane Management

```bash
# Create AI pane manually
ai-pane create

# Toggle AI pane
ai-pane toggle

# Close AI pane
ai-pane close
```

### tmux Configuration

The system modifies `~/.tmux.conf` with:
- Ctrl-A prefix (instead of Ctrl-B)
- Vi-mode keys
- AI integration keybindings
- Enhanced pane navigation

## Troubleshooting

```bash
# Commands not found
source ~/.bashrc  # or ~/.zshrc
chmod +x ~/.config/shell-ai/*.sh

# AI not responding  
ai-test
ai-setup

# tmux issues
tmux source-file ~/.tmux.conf

# Debug
ai --context
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

```bash
# Main commands
ai [OPTIONS] [PROMPT]              # Main AI integration
ai-setup                           # Interactive configuration
ai-copy                           # Response management
ai-last                           # Explain last command
ai-here [context]                 # Ask about current directory
ai-fix                            # Fix last failed command
ai-test                           # Test providers

# Key options
--help, --test, --context
--provider [openai|anthropic|google|ollama]
--history-lines N, --pane-lines N
--no-history, --no-pane
``` 