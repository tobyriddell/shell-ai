# Shell AI Integration

<p align="center">
  <img src="media/shell-ai-logo-transparent.png" alt="Shell AI Logo" width="200">
</p>

An AI-enhanced shell environment that seamlessly integrates multiple AI providers with your command-line workflow. Get intelligent assistance, command explanations, and context-aware suggestions directly in your terminal.

> **🚀 RECOMMENDED: Go Implementation**  
> **The Go implementation (`shell-ai-go/`) is the primary version** and supersedes the original bash implementation. It offers enhanced performance, better error handling, conversational context, and improved tmux integration. [Jump to Go Installation](#go-implementation-recommended)

> **⚠️ LEGACY: Bash Implementation**  
> **The bash implementation is deprecated** and maintained for backward compatibility only. New users should use the Go implementation.

## 🚀 Features

### Core Features (Both Implementations)
- **Multi-Provider AI Support**: OpenAI, Anthropic, Google Gemini, and Ollama
- **Smart Context Capture**: Automatically includes shell history (via atuin) and tmux pane content
- **Response Management**: AI output can be extracted and executed safely
- **Enhanced History**: Integrates with atuin for superior command history
- **tmux Integration**: Seamless pane selection and command distribution

### Go Implementation Enhancements (Recommended)
- **🔄 Conversational Context**: Multi-turn conversations with full context retention
- **⚡ High Performance**: Fast startup (~50ms) and efficient resource usage
- **🛡️ Advanced Safety**: Intelligent command safety analysis with real-time feedback
- **🎨 Rich Terminal UI**: Syntax highlighting, colored output, and interactive menus
- **🎯 Smart Pane Selection**: Built-in tmux pane selector with visual navigation
- **⌨️ Interactive Sessions**: Full shell-like experience with Ctrl-D termination
- **🧪 Comprehensive Testing**: 85%+ test coverage with robust error handling

### Bash Implementation Features (Legacy - Deprecated)
- **Modular Architecture**: Runtime provider loading for easy customization
- **Two Prompt Methods**: `@` prefix queries and dedicated tmux panes  
- **Docker Development**: Pre-configured containers for bash and zsh
- **⚠️ Note**: This implementation is maintained for backward compatibility only

## 📋 Installation & Quick Start

## Go Implementation (Recommended)

### Prerequisites
- Go 1.21 or later
- tmux (for tmux integration)
- atuin (optional, for enhanced history)

### Installation

1. **Clone and Build**:
   ```bash
   git clone <repository-url>
   cd shell-ai/shell-ai-go
   make build
   ```

2. **Install to PATH**:
   ```bash
   make install
   # Or manually: cp build/shell-ai ~/.local/bin/
   ```

3. **Configure AI Providers**:
   ```bash
   shell-ai setup
   ```

### Usage

**Interactive Session (Recommended)**:
```bash
shell-ai interactive
# Or just: shell-ai
```

**One-shot Queries**:
```bash
shell-ai ask "how do I find large files?"
shell-ai ask --provider openai "explain this error"
```

**Available Commands**:
- `shell-ai interactive` - Start conversational session
- `shell-ai ask <prompt>` - Single question
- `shell-ai setup` - Configure providers
- `shell-ai test` - Test provider connections
- Use `Ctrl-D` to exit interactive sessions

---

## Bash Implementation (Legacy - Deprecated)

> **⚠️ DEPRECATED**: The bash implementation is maintained for backward compatibility only.  
> **🚀 RECOMMENDED**: Use the Go implementation above for the best experience.

### Native Installation (Legacy)

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

#### Go Implementation

The Go version uses YAML configuration in `~/.config/shell-ai/config.yaml`:

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

Use `shell-ai setup` for interactive configuration.

#### Bash Implementation (Legacy)

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

## 🔧 Modular Architecture

The shell-ai system uses a modular architecture where AI providers are loaded at runtime from separate files. This allows for easy customization and environment-specific deployments.

### Provider Structure

```
~/.config/shell-ai/
├── providers/
│   ├── openai.sh      # OpenAI provider
│   ├── anthropic.sh   # Anthropic provider
│   ├── google.sh      # Google Gemini provider
│   └── ollama.sh      # Ollama provider
├── ai-shell.sh        # Main shell integration
└── ai-setup.sh        # Configuration script
```

### Custom Providers

You can create custom providers by:

1. Create a new file in `~/.config/shell-ai/providers/`
2. Implement the required functions:
   - `call_<provider>()` - Handle AI API calls
   - `setup_<provider>()` - Handle configuration
   - Set `PROVIDER_NAME` and `PROVIDER_DESCRIPTION` variables

3. The provider will be automatically discovered and loaded

### Environment-Specific Deployments

For environments requiring different provider sets:
- Include only the needed provider files in the `providers/` directory
- The system will automatically adapt to available providers
- No code changes needed in the main scripts

## 💡 Usage Examples

### Go Implementation (Recommended)

#### Interactive Session
```bash
# Start conversational session
shell-ai interactive

# In interactive mode:
🤖 AI> How do I find large files?
# AI responds with commands and explanations

🤖 AI> /send  # Send last commands to tmux pane
🤖 AI> /context  # Show current context
🤖 AI> /clear  # Clear conversation
🤖 AI> /help  # Show help
🤖 AI> Ctrl-D  # Exit
```

#### One-shot Queries
```bash
shell-ai ask "explain the ps command"
shell-ai ask --provider openai "fix this error: permission denied"
shell-ai ask --no-history "what is tmux?"
```

#### tmux Integration
The Go implementation includes built-in pane selection:
- Automatically detects tmux environment
- Visual pane selector with arrow key navigation
- Safe command execution with confirmation
- Context includes all pane content

### Bash Implementation (Legacy)

#### Command Line (bash/zsh)
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

#### tmux Integration
**Keybindings** (Ctrl-A prefix key assumed):
- `A`: Toggle AI input pane
- `I`: Quick AI query prompt  
- `C`: AI response manager
- `T`: Test AI providers
- `X`: Show AI context

**Workflow**: `Ctrl-A + A` → type query → use `ai-copy` to execute responses

## 🧪 Testing

### Go Implementation

```bash
cd shell-ai-go

# Run all tests
make test

# Verbose output
make test-verbose

# Coverage report
make test-coverage

# Run specific packages
go test ./pkg/ai ./pkg/tmux

# Build and test
make build && ./build/shell-ai --help
```

### Bash Implementation (Legacy)

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
├── shell-ai-go/          # 🚀 Go Implementation (Recommended)
│   ├── main.go           # CLI entry point
│   ├── Makefile          # Build automation
│   ├── pkg/              # Go packages
│   │   ├── ai/           # AI provider management
│   │   ├── config/       # Configuration handling
│   │   ├── contextgather/# Context collection
│   │   ├── session/      # Interactive sessions
│   │   ├── tmux/         # tmux integration
│   │   └── response/     # Response parsing
│   ├── scripts/          # Helper scripts
│   └── build/            # Compiled binaries
├── install.sh            # Bash implementation installer (Legacy)
├── Dockerfile.{bash,zsh} # Development environments
├── Makefile              # Docker build automation
├── scripts/              # 📜 Bash AI integration scripts (Legacy)
│   ├── ai-shell.sh       # Main AI integration
│   ├── ai-setup.sh       # Provider configuration
│   └── ai-copy.sh        # Response management
├── config/               # Configuration files (Shared)
│   ├── bashrc-ai.sh      # Bash integration
│   ├── zshrc-ai.sh       # Zsh integration
│   └── tmux.conf         # tmux configuration
├── providers/            # AI provider scripts (Shared)
└── tests/                # Test suite (Both implementations)
```

## 🔧 Dependencies

### Go Implementation
**Required**: Go 1.21+, tmux 3.5+  
**Optional**: atuin (enhanced history)

```bash
# Ubuntu/Debian
sudo apt-get install golang tmux

# macOS  
brew install go tmux

# Install atuin (optional)
curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | sh
```

### Bash Implementation (Legacy - Deprecated)
> **⚠️ DEPRECATED**: Use the Go implementation above instead.

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

### Go Implementation

```bash
# Test providers
shell-ai test

# Check configuration
shell-ai setup

# Show context
shell-ai ask --no-history --no-panes "test"

# Build issues
cd shell-ai-go && make clean && make build

# Debug with verbose output
make test-verbose
```

### Bash Implementation (Legacy - Deprecated)

> **⚠️ DEPRECATED**: Use the Go implementation troubleshooting above instead.

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

## 🔄 Migration from Bash to Go

> **⚠️ IMPORTANT**: The bash implementation is deprecated. Please migrate to the Go implementation.

If you're currently using the bash implementation:

1. **Install Go Implementation**:
   ```bash
   cd shell-ai/shell-ai-go
   make build && make install
   ```

2. **Configuration Migration**:
   - Go implementation uses YAML format instead of JSON
   - Run `shell-ai setup` to create new configuration
   - Your existing `~/.config/shell-ai/` directory is compatible

3. **Usage Changes**:
   - Replace `ai "query"` with `shell-ai ask "query"`
   - Use `shell-ai interactive` for conversational sessions
   - tmux integration is built-in (no separate keybindings needed)

4. **Benefits**:
   - Much faster startup and response times
   - Better error handling and debugging
   - Conversational context across multiple queries
   - Enhanced safety analysis of commands

## 🤝 Contributing

### Go Implementation (Preferred)
1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes in `shell-ai-go/`
4. Run tests: `cd shell-ai-go && make test`
5. Ensure code quality: `make fmt lint`
6. Submit pull request

**Development**: `cd shell-ai-go && make dev`

### Bash Implementation (Maintenance Only)
1. Fork repository
2. Create feature branch  
3. Test with `make test`
4. Submit pull request

**Development**: `make dev-bash` or `make dev-zsh`

## 📄 License

MIT License - see LICENSE file for details.

## 🚀 Roadmap

### Go Implementation (Active Development)
- [ ] **Streaming Responses**: Real-time AI response streaming
- [ ] **Additional Providers**: Anthropic, Google, Ollama implementations  
- [ ] **Plugin System**: Custom provider plugins
- [ ] **History Search**: Semantic conversation search
- [ ] **Web UI**: Browser-based interface
- [ ] **Team Features**: Shared conversation contexts

### Bash Implementation (Maintenance Mode)
- [x] Core functionality complete
- [ ] Critical bug fixes only
- [ ] **Migration to Go encouraged**

## 🔗 Related Projects

- [atuin](https://github.com/ellie/atuin) - Enhanced shell history
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [OpenAI API](https://openai.com/api/) - GPT models
- [Anthropic Claude](https://www.anthropic.com/) - Claude models  
- [Ollama](https://ollama.ai/) - Local LLM inference

---

> **🚀 Ready to upgrade your shell experience?**  
> **Start with the Go implementation**: `cd shell-ai-go && make build`  
> **The future of shell AI is here!** 🤖✨ 
