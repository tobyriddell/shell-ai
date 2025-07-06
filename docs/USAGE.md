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
      "model": "gemini-pro",
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