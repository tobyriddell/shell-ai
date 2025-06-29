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

### Docker Installation (Recommended)

```bash
# Clone repository
git clone <repository-url>
cd shell-ai

# Build image
docker build -t shell-ai .

# Run with persistent configuration
cp config/ai-config.json my-config.json
# Edit my-config.json with your API keys

docker run -it -v $(pwd)/my-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai
```

### Native Installation

```bash
# Clone and install
git clone <repository-url>
cd shell-ai
chmod +x install.sh
./install.sh

# Reload shell
source ~/.bashrc
```

## Configuration

### Initial Setup

Run the interactive configuration:

```bash
ai-setup
```

This will guide you through:
1. Selecting AI providers
2. Entering API keys
3. Choosing models
4. Testing connections

### Manual Configuration

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

### API Key Security

```bash
# Secure your config file
chmod 600 ~/.config/shell-ai/config.json

# Use environment variables (optional)
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
```

## Basic Usage

### Command Line Queries

#### @ Prefix Method

```bash
# Quick questions
@what does ps aux do
@how to find files larger than 100MB
@explain the difference between grep and egrep

# Error troubleshooting  
@fix this error: bash: command not found
@why am I getting permission denied

# Code assistance
@write a bash script to backup my home directory
@how to parse JSON in bash
```

#### Direct Commands

```bash
# Basic AI query
ai "explain the ls command"

# With specific provider
ai --provider anthropic "help me debug this script"

# Context-aware queries
ai-here "what are these files used for?"
ai-last "explain what this command does"
ai-fix "the last command failed, how do I fix it?"
```

### Context Control

```bash
# Show what context will be sent
ai --context

# Exclude shell history
ai --no-history "help me with docker"

# Exclude tmux pane content
ai --no-pane "general bash question"

# Limit context size
ai --history-lines 10 --pane-lines 20 "analyze this output"
```

## Advanced Features

### Response Management

After receiving an AI response, use `ai-copy` to:

```bash
ai-copy
# Interactive menu:
# 1. Show full response
# 2. Copy commands to current shell  
# 3. Send to tmux pane
# 4. Extract and show commands only
```

### Specialized Commands

```bash
# Explain the last command you ran
ai-last

# Get help with current directory
ai-here "how do I organize these files?"

# Fix the last failed command
somecommand  # This fails
ai-fix       # AI suggests fixes
```

### Context-Aware Queries

The AI receives:
- **System info**: OS, shell, current directory
- **Command history**: Recent commands (via atuin)
- **Terminal output**: Current tmux pane content
- **Environment**: Working directory contents

Example workflow:
```bash
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

### Common Issues

#### 1. Commands Not Found

```bash
# Check if scripts are in PATH
echo $PATH | grep shell-ai

# Reload configuration
source ~/.bashrc

# Check script permissions
ls -la ~/.config/shell-ai/
chmod +x ~/.config/shell-ai/*.sh
```

#### 2. AI Not Responding

```bash
# Test providers
ai-test

# Check configuration
ai-setup

# View current config
cat ~/.config/shell-ai/config.json

# Check API key format
ai --provider openai "test" --context
```

#### 3. tmux Issues

```bash
# Reload tmux config
tmux source-file ~/.tmux.conf

# Check tmux version
tmux -V  # Requires 2.1+

# List current keybindings
tmux list-keys | grep -i ai
```

#### 4. Permission Errors

```bash
# Fix script permissions
chmod +x ~/.config/shell-ai/*.sh

# Secure config file
chmod 600 ~/.config/shell-ai/config.json

# Check file ownership
ls -la ~/.config/shell-ai/
```

### Debug Mode

```bash
# Show context being sent
ai --context

# Test specific provider
ai --provider openai --test

# Verbose output
ai "test query" --history-lines 5 --pane-lines 10
```

## API Reference

### ai-shell.sh

Main AI integration script.

```bash
ai [OPTIONS] [PROMPT]

Options:
  -h, --help          Show help
  -t, --test          Test AI provider connection
  -c, --context       Show context sent to AI
  -p, --provider      Specify provider (openai, anthropic, google, ollama)
  --history-lines N   Number of history lines (default: 50)
  --pane-lines N      Number of pane lines (default: 100)
  --no-history        Don't include shell history
  --no-pane           Don't include tmux pane content

Examples:
  ai "explain this command: ps aux"
  ai --provider anthropic --no-history "help with docker"
  ai --context  # Show what context would be sent
```

### ai-setup.sh

Interactive configuration utility.

```bash
ai-setup

# Interactive menu with options:
# 1. OpenAI (GPT-3.5/GPT-4)
# 2. Anthropic (Claude)
# 3. Google (Gemini)
# 4. Ollama (Local)
# 5. View current configuration
# 6. Test AI integration
# 0. Exit
```

### ai-copy.sh

Response management utility.

```bash
ai-copy

# Interactive menu:
# 1. Show full response
# 2. Copy commands to current shell
# 3. Send to tmux pane
# 4. Extract and show commands only
# 0. Exit
```

### Helper Functions

```bash
# Explain last command
ai-last

# Ask about current directory
ai-here [additional context]

# Fix last failed command
ai-fix

# Show AI context
ai-context

# Test providers
ai-test

# Toggle tmux AI pane
ai-pane
```

## Best Practices

### Effective Prompting

```bash
# Be specific
ai "explain the grep -r flag with examples"

# Provide context
ai-here "I need to compress these files, what's the best method?"

# Ask for alternatives
ai "show me 3 different ways to find files modified today"
```

### Security

```bash
# Secure your config
chmod 600 ~/.config/shell-ai/config.json

# Use environment variables in scripts
export OPENAI_API_KEY="..."

# Review AI responses before executing
ai-copy  # Don't blindly execute suggestions
```

### Performance

```bash
# Limit context for faster responses
ai --history-lines 10 --pane-lines 20 "quick question"

# Use local models for frequent queries
ai-setup  # Configure Ollama

# Test multiple providers
ai-test  # Find the fastest/most reliable
```

## Integration Examples

### Development Workflow

```bash
# Start tmux session
tmux new-session -s dev

# Create AI pane
# Press Ctrl-A + A

# Query in AI pane
ai "help me debug this Python script"

# Execute suggestions in main pane
ai-copy  # Extract and run commands
```

### System Administration

```bash
# Analyze logs
cd /var/log
@analyze these system logs for errors

# Fix permissions
chmod 755 file.sh  # This fails
ai-fix  # Get correction

# Monitor processes
ps aux | grep mysql
ai-last  # Explain the command
```

### Learning and Exploration

```bash
# Explore new tools
which docker
ai-here "I want to learn Docker, where do I start?"

# Understand complex commands
find . -name "*.log" -mtime +7 -delete
ai-last  # Get detailed explanation
```

This comprehensive guide covers all aspects of using the Shell AI Integration system. For additional help, use the built-in help commands or consult the main README.md file. 