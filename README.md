# Shell AI Integration

<p align="center">
  <img src="media/shell-ai-logo-transparent.png" alt="Shell AI Logo" width="200">
</p>

An AI-enhanced shell environment that seamlessly integrates multiple AI providers with your command-line workflow. Get intelligent assistance, command explanations, and context-aware suggestions directly in your terminal.

## 🚀 Features

- **Multi-Provider AI Support**: OpenAI, Anthropic, Google Gemini, and Ollama
- **🔄 Conversational Context**: Multi-turn conversations with full context retention
- **⚡ High Performance**: Fast startup (~50ms) and efficient resource usage
- **🛡️ Advanced Safety**: Intelligent command safety analysis with real-time feedback
- **🎨 Rich Terminal UI**: Syntax highlighting, colored output, and interactive menus
- **🎯 Smart Pane Selection**: Built-in tmux pane selector with visual navigation
- **⌨️ Interactive Sessions**: Full shell-like experience with Ctrl-D termination
- **Smart Context Capture**: Automatically includes shell history (via atuin) and tmux pane content
- **Response Management**: AI output can be extracted and executed safely
- **Enhanced History**: Integrates with atuin for superior command history
- **tmux Integration**: Seamless pane selection and command distribution
- **🧪 Comprehensive Testing**: 85%+ test coverage with robust error handling

## 📋 Installation & Quick Start

### Prerequisites
- Go 1.21 or later
- tmux (for tmux integration)
- atuin (optional, for enhanced history)

### Quick Installation

```bash
# Clone the repository
git clone <repository-url>
cd shell-ai

# Build and install (installs to ~/.local/bin/)
make install

# Configure AI providers
shell-ai setup

# Add to PATH if not already (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc  # or source ~/.zshrc

# Reload tmux configuration
tmux source-file ~/.tmux.conf
```

### Alternative: System-wide Installation

```bash
# Install to /usr/local/bin (requires sudo)
make install-system
shell-ai setup
```

### Manual Installation

If you prefer manual installation:

```bash
# Build the binary
cd shell-ai-go
make build

# Install to your preferred location
cp build/shell-ai ~/.local/bin/shell-ai
chmod +x ~/.local/bin/shell-ai

# Copy tmux configuration
cp ../config/tmux.conf ~/.tmux.conf

# Configure
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

**Shell Aliases** (automatically configured):
- `ai` → `shell-ai ask`
- `ai-interactive` → `shell-ai interactive`
- `ai-setup` → `shell-ai setup`
- `ai-test` → `shell-ai test`

**tmux Keybindings** (Ctrl-A prefix):
- `Ctrl-A + S` - Start interactive AI session
- `Ctrl-A + I` - Quick AI query with prompt
- `Ctrl-A + Q` - One-shot AI query
- `Ctrl-A + T` - Test AI providers
- `Ctrl-A + E` - Explain current pane output
- `Ctrl-A + X` - Show AI context

## 🔧 Configuration

### AI Provider Configuration

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
    model: "gemini-2.5-pro"
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

## 💡 Usage Examples

### Interactive Session

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

### One-shot Queries

```bash
shell-ai ask "explain the ps command"
shell-ai ask --provider openai "fix this error: permission denied"
shell-ai ask --no-history "what is tmux?"
```

### tmux Integration

The Go implementation includes built-in pane selection:
- Automatically detects tmux environment
- Visual pane selector with arrow key navigation
- Safe command execution with confirmation
- Context includes all pane content

## 🧪 Testing

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

## 📁 Project Structure

```
shell-ai/
├── shell-ai-go/          # Go Implementation
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
├── Makefile              # Build and installation automation
├── config/               # Configuration files
│   ├── bashrc-ai.sh      # Bash integration
│   ├── zshrc-ai.sh       # Zsh integration
│   └── tmux.conf         # tmux configuration
└── tests/                # Test suite
    └── test_docker_go.sh # Go implementation tests
```

## 🔧 Dependencies

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

## 🐛 Troubleshooting

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

## 🤝 Contributing

1. Fork repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes in `shell-ai-go/`
4. Run tests: `cd shell-ai-go && make test`
5. Ensure code quality: `make fmt lint`
6. Submit pull request

**Development**: `cd shell-ai-go && make dev`

## 📄 License

MIT License - see LICENSE file for details.

## 🚀 Roadmap

- [ ] **Streaming Responses**: Real-time AI response streaming
- [ ] **Additional Providers**: Enhanced Anthropic, Google, Ollama implementations  
- [ ] **Plugin System**: Custom provider plugins
- [ ] **History Search**: Semantic conversation search
- [ ] **Web UI**: Browser-based interface
- [ ] **Team Features**: Shared conversation contexts

## 🔗 Related Projects

- [atuin](https://github.com/ellie/atuin) - Enhanced shell history
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [OpenAI API](https://openai.com/api/) - GPT models
- [Anthropic Claude](https://www.anthropic.com/) - Claude models  
- [Ollama](https://ollama.ai/) - Local LLM inference

---

> **🚀 Ready to upgrade your shell experience?**  
> **Start with**: `cd shell-ai-go && make build`  
> **The future of shell AI is here!** 🤖✨
