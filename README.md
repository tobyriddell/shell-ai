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

## 📋 Installation

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

## 💡 Usage

### Interactive Session (Recommended)

```bash
shell-ai interactive
# Or just: shell-ai
```

In interactive mode:
- Type your questions naturally
- Use `/send` to send commands to tmux panes
- Use `/context` to view current context
- Use `/clear` to clear conversation history
- Use `/help` for available commands
- Press `Ctrl-D` to exit
- Prompt displays live context usage (e.g., `[████░░░░░] 50% 🤖 AI>`) so you know when you're nearing limits.

### One-shot Queries

```bash
shell-ai ask "how do I find large files?"
shell-ai ask --provider openai "explain this error"
shell-ai ask --no-history "what is tmux?"  # Exclude shell history
shell-ai ask --no-panes "query"            # Exclude tmux content
```

### Helper Functions

```bash
ai-last    # Explain last command
ai-here    # Ask about current directory
ai-fix     # Fix last failed command
```

### Commands & Aliases

**Main Commands:**
- `shell-ai interactive` - Start conversational session
- `shell-ai ask <prompt>` - Single question
- `shell-ai setup` - Configure providers
- `shell-ai test` - Test provider connections

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
- `Ctrl-A + C` - AI copy manager (interactive mode)

**Interactive Slash Commands:**
- `/context` – Show the fully gathered context block
- `/context-usage` – Show current context usage (size + percentage + bar)
- `/context-max <bytes|KB|MB>` – Update the max context size on the fly (persists to config)
- `/stats` – Detailed context stats (tokens, size, messages)

## 🔧 Configuration

### Interactive Setup

```bash
shell-ai setup
```

This guides you through:
1. Selecting AI providers to enable
2. Entering API keys securely
3. Configuring model preferences
4. Setting up context and conversation settings

### Configuration File

Configuration is stored in `~/.config/shell-ai/config.yaml`:

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
  default_prompt: "Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed."
  max_history_lines: 50
  max_pane_lines: 100              # Maximum lines captured per tmux pane
  max_pane_context_size: 20000     # Maximum total size (bytes) for all pane content combined
  conversation_ttl_hours: 24
```

**Settings:**
- `default_prompt`: The default prompt appended to all user queries (default: "Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed."). Customize this to change how the AI responds to your queries.
- `max_pane_lines`: Maximum number of lines captured from each tmux pane (default: 100). Applied per pane before the total size limit.
- `max_pane_context_size`: Maximum total size in bytes for all tmux pane content combined (default: 20000 = 20KB). Panes from the current window are prioritized over panes from other windows.

**Secure Configuration:**
```bash
chmod 600 ~/.config/shell-ai/config.yaml
```

## 🎯 Advanced Features

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
- Current tmux pane content (prioritized by window)
- Working directory and file listings
- Previous conversation context

### Conversation Context

The Go implementation maintains conversation context across multiple queries:
- Context is automatically included in follow-up questions
- Context expires after 24 hours (configurable via `conversation_ttl_hours`)
- Use `/clear` in interactive mode to reset context

## 🐛 Troubleshooting

### Common Issues

```bash
# Commands not found
source ~/.bashrc  # or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# AI not responding
shell-ai test
shell-ai setup

# tmux issues
tmux source-file ~/.tmux.conf

# Check configuration
cat ~/.config/shell-ai/config.yaml

# Build issues
cd shell-ai-go && make clean && make build
```

### zsh Globbing Issues

**Problem**: In zsh, special characters like `?` and `*` in prompts can cause globbing errors.

**Solution** (Recommended): Add to `~/.zshrc` or `~/.config/shell-ai/zshrc-ai.sh`:
```bash
setopt nonomatch  # Prevent zsh from failing on unmatched glob patterns
```

**Alternative**: Quote prompts containing special characters:
```bash
ai "What is the speed of light?"
```

## 🐛 Debug Mode

Shell AI includes a compile-time debug mode that logs all prompts, context, and conversation summaries to `~/.config/shell-ai/debug.log`.

To build with debug mode enabled:

```bash
cd shell-ai-go
make build-debug
```

Or manually:

```bash
cd shell-ai-go
go build -tags debug -o build/shell-ai ./cmd/shell-ai
```

When debug mode is enabled, the following information is logged to `~/.config/shell-ai/debug.log`:
- **All prompts**: Complete prompts sent to the LLM, including context and user queries
- **Context data**: System information, shell history, tmux pane content, and environment variables
- **Conversation summaries**: Current conversation state with message counts and previews

Debug logging is disabled by default and has no performance impact when not compiled with the `debug` tag.

## 🧪 Testing

```bash
cd shell-ai-go

# Run all tests
make test

# Verbose output
make test-verbose

# Coverage report
make test-coverage
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
