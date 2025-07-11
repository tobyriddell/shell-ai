# Shell AI Integration

<p align="center">
  <img src="media/shell-ai-logo-transparent.png" alt="Shell AI Logo" width="200">
</p>

An AI-enhanced shell environment that seamlessly integrates multiple AI providers with your command-line workflow. Get intelligent assistance, command explanations, and context-aware suggestions directly in your terminal.

## 🚀 Features

- **Multi-Provider AI Support**: OpenAI, Anthropic, Google Gemini, and Ollama
- **Multi-Shell Support**: Native bash and zsh integration with shell-specific optimizations
- **Smart Context Capture**: Automatically includes shell history (via atuin) and tmux pane content
- **Two Prompt Methods**: 
  - `@` prefix for quick queries: `@how do I find large files`
  - Dedicated tmux pane for AI interactions
- **Response Management**: AI output can be extracted and executed safely
- **Enhanced History**: Integrates with atuin for superior command history
- **Docker Development Environment**: Pre-configured containers for both bash and zsh

## 📋 Quick Start

### Native Installation (Recommended)

1. **Install**:
   ```bash
   git clone <repository-url>
   cd shell-ai
   chmod +x install.sh
   ./install.sh
   ```

2. **Reload Shell**:
   ```bash
   source ~/.bashrc  # bash
   source ~/.zshrc   # zsh
   ```

3. **Configure AI**:
   ```bash
   ai-setup
   ```

## 🐳 Docker Development 

```bash
# Build images
make all             # Build both bash/zsh
make bash            # Build bash only  
make zsh             # Build zsh only

# Build and run
make run-bash    # or make run-zsh
make dev-bash    # Development with project mounted
make test        # Run tests

# Development
make dev-bash        # Development environment (bash)
make dev-zsh         # Development environment (zsh)
make run-bash-config # Run with config mounted
make run-zsh-config  # Run with config mounted

# Testing
make test            # Run all tests
make test-bash       # Test bash only
make test-zsh        # Test zsh only
```

## 🔧 Configuration

### AI Provider Configuration

> **⚠️ Note**: Only the Google LLM provider has been thoroughly tested - PRs are welcome for others!

Edit `~/.config/shell-ai/config.json` or use `ai-setup`:

```json
{
  "providers": {
    "openai": {
      "api_key": "sk-...",
      "model": "gpt-3.5-turbo",
      "enabled": true
    },
    "anthropic": {
      "api_key": "sk-ant-...",
      "model": "claude-3-haiku-20240307",
      "enabled": false
    },
    "google": {
      "api_key": "AI...",
      "model": "gemini-2.5-flash",
      "enabled": false
    },
    "ollama": {
      "host": "http://localhost:11434",
      "model": "llama2",
      "enabled": false
    }
  }
}
```

### Environment Variables

For Docker containers, you can also use environment variables:

```bash
docker run -it \
  -e OPENAI_API_KEY="sk-..." \
  -e AI_PROVIDER="openai" \
  shell-ai
```

## 💡 Usage Examples

### Command Line (bash/zsh)

```bash
# @ prefix queries
@explain the ps command
@fix this error: permission denied  
@how do I find files larger than 1GB

# Direct commands
ai "help me write a script to backup files"
ai-last    # Explain last command
ai-fix     # Fix last failed command
ai-here    # Ask about current directory
```

### tmux Integration

**Keybindings** (Ctrl-A prefix key assumed):
- `A`: Toggle AI input pane
- `I`: Quick AI query prompt  
- `C`: AI response manager
- `T`: Test AI providers
- `X`: Show AI context

**Workflow**: `Ctrl-A + A` → type query → use `ai-copy` to execute responses

## 🧪 Testing

```bash
# Native testing
./tests/test_runner.sh

# Docker testing  
make test           # Test both shells
make test-bash      # Test bash only
make test-zsh       # Test zsh only
```

## 📁 Project Structure

```
shell-ai/
├── install.sh             # Installation script
├── Dockerfile.{bash,zsh}  # Development environments
├── Makefile               # Docker build automation
├── scripts/               # AI integration scripts
│   ├── ai-shell.sh        # Main AI integration
│   ├── ai-setup.sh        # Provider configuration
│   └── ai-copy.sh         # Response management
├── config/                # Configuration files
│   ├── bashrc-ai.sh       # Bash integration
│   ├── zshrc-ai.sh        # Zsh integration
│   └── tmux.conf          # tmux configuration
└── tests/                 # Unit tests (bash/zsh)
```

## 🔧 Dependencies

**Required**: `bash`/`zsh`, `curl`, `jq`, `tmux` 3.5+  
**Optional**: `atuin` (enhanced history), Docker (development)

```bash
# Ubuntu/Debian
sudo apt-get install bash zsh curl jq tmux

# macOS  
brew install bash zsh curl jq tmux

# RHEL/CentOS
sudo yum install bash zsh curl jq tmux
```

## 🐛 Troubleshooting

```bash
# AI not responding
ai-test

# Commands not found  
source ~/.bashrc  # or ~/.zshrc

# tmux keybindings not working
tmux source-file ~/.tmux.conf

# Permission errors
chmod +x ~/.config/shell-ai/*.sh

# Debug
ai --context     # Show context sent to AI
ai-setup         # Reconfigure providers
```

## 🤝 Contributing

1. Fork repository
2. Create feature branch  
3. Test with `make test`
4. Submit pull request

**Development**: `make dev-bash` or `make dev-zsh`

## 📄 License

MIT License - see LICENSE file for details.

## 🔗 Related Projects

- [atuin](https://github.com/ellie/atuin) - Enhanced shell history
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [OpenAI API](https://openai.com/api/) - GPT models
- [Anthropic Claude](https://www.anthropic.com/) - Claude models  
- [Ollama](https://ollama.ai/) - Local LLM inference

---

**Happy AI-assisted shell scripting! 🤖✨** 
