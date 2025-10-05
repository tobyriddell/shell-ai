# Shell AI Go Implementation

A high-performance Go implementation of shell-ai with enhanced conversational context, tmux integration, and interactive session management.

> **⚡ This is the recommended implementation** and supersedes the original bash version. See the [main documentation](../README.md) for full project details and migration guide.

## 🚀 Features

### Enhanced Conversation Management
- **Multi-turn Conversations**: Maintain context across multiple interactions
- **Session Persistence**: Resume conversations with full context
- **Ctrl-D Termination**: Graceful session exit like a regular shell

### Advanced tmux Integration
- **Integrated Pane Selector**: Built-in tmux pane selection with interactive navigation
- **Smart Command Sending**: Safety-checked command execution
- **Context-Aware**: Includes tmux pane content in AI context

### Improved Context Gathering
- **Enhanced Atuin Integration**: Better shell history handling
- **System Information**: Comprehensive environment context
- **Multi-shell Support**: Bash, zsh, and other shells

### Safety & Usability
- **Command Safety Analysis**: Automatic dangerous command detection
- **Interactive Confirmation**: Preview commands before execution
- **Rich Terminal UI**: Syntax highlighting and colored output

## 📋 Installation

### Prerequisites
- Go 1.21 or later
- tmux (for tmux integration)
- atuin (optional, for enhanced history)

### Quick Install
```bash
# Clone repository
git clone <repository-url>
cd shell-ai/shell-ai-go

# Build
make build

# Install to PATH
make install
```

### Development Setup
```bash
# Install development dependencies
make dev-deps

# Run tests
make test

# Build and run
make dev
```

## 🔧 Configuration

The Go implementation uses the same configuration format as the original shell-ai:

```yaml
# ~/.config/shell-ai/config.yaml
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

settings:
  auto_copy: false
  auto_copy_prompt: true
  max_history_lines: 50
  max_pane_lines: 100
  conversation_ttl_hours: 24
```

### Setup Configuration
```bash
# Interactive setup
shell-ai setup

# Test providers
shell-ai test
```

## 💡 Usage

### Interactive Session (Recommended)
```bash
# Start conversational session
shell-ai interactive

# Or just
shell-ai
```

**Interactive Commands:**
- Type questions naturally
- `/help` - Show help
- `/context` - Show current context
- `/clear` - Clear conversation
- `/send` - Send last response to tmux pane
- `/provider <name>` - Switch AI provider
- `/quit` or `Ctrl-D` - Exit

### One-Shot Queries
```bash
# Single question
shell-ai ask "how do I find large files?"

# With specific provider
shell-ai --provider openai ask "explain this error"

# Disable context
shell-ai --no-history --no-panes ask "what is tmux?"
```

### Command Line Options
```bash
shell-ai [command] [flags]

Commands:
  interactive     Start interactive session (default)
  ask [prompt]    Ask a single question
  setup           Configure AI providers
  test            Test provider connections

Global Flags:
  --config string        config file (default ~/.config/shell-ai/config.yaml)
  --provider string      AI provider to use
  --context-lines int    number of context lines (default 50)
  --no-history          exclude shell history
  --no-panes            exclude tmux content
```

## 🔄 tmux Integration

### Automatic Integration
When running in tmux, shell-ai automatically:
- Captures content from all panes
- Includes pane information in AI context
- Provides pane selection for command execution

### tmux Workflow
1. **Ask Question**: In interactive session or one-shot
2. **Review Response**: AI provides commands and explanations
3. **Send to Pane**: Use `/send` or command extraction
4. **Execute Safely**: Review commands before execution

### Pane Selection
The built-in pane selector provides:
- **Visual Selection**: Arrow keys or vim navigation
- **Smart Defaults**: Auto-selects most recent pane
- **Rich Display**: Shows pane titles and activity

## 🧪 Command Safety

Shell-ai Go includes advanced command safety analysis:

### Safety Indicators
- ✅ **Safe Commands**: Basic operations (ls, pwd, cat)
- ⚠️ **Dangerous Commands**: System-modifying operations

### Dangerous Patterns
- File system modifications (`rm`, `dd`, `mkfs`)
- Permission changes (`chmod`, `chown`, `sudo`)
- System control (`systemctl`, `reboot`)
- Network downloads piped to shell

### Safety Features
- **Interactive Confirmation**: Preview before execution
- **Batch Safety Check**: Analyze all commands at once
- **Context Awareness**: Understand command intent

## 🔧 Development

### Project Structure
```
shell-ai-go/
├── main.go                 # CLI entry point
├── pkg/
│   ├── ai/                 # AI provider interfaces
│   │   ├── manager.go      # Provider management
│   │   ├── types.go        # Core types
│   │   └── providers/      # Provider implementations
│   ├── config/             # Configuration management
│   ├── context/            # Context gathering
│   ├── session/            # Session management
│   ├── tmux/               # tmux integration
│   └── response/           # Response parsing
├── scripts/                # Helper scripts
└── tests/                  # Test files
```

### Building
```bash
# Development build
make build

# Optimized release
make build-release

# Cross-platform builds
make build-all
```

### Testing
```bash
# Run all tests
make test

# Verbose output
make test-verbose

# Coverage report
make test-coverage

# Benchmarks
make bench
```

### Code Quality
```bash
# Format code
make fmt

# Run linter
make lint

# All quality checks
make fmt lint test
```

## 🔗 Integration with Original Shell-AI

The Go implementation is designed to work alongside the original shell-ai:

### Shared Configuration
- Uses same config directory (`~/.config/shell-ai`)
- Compatible configuration format
- Shared response files for ai-copy integration

### Migration Path
```bash
# Link Go binary to shell-ai config
make link-to-config

# Use with existing scripts
shell-ai-copy.sh  # Enhanced copy script for Go version
```

### Compatibility
- Works with existing tmux configurations
- Compatible with atuin history
- Same command extraction format

## 📊 Performance

Go implementation advantages:
- **Fast Startup**: < 50ms cold start
- **Low Memory**: Efficient resource usage
- **Concurrent**: Parallel context gathering
- **Cross-Platform**: Single binary deployment

## 🐛 Troubleshooting

### Common Issues

**Binary not found:**
```bash
# Check build
make build
ls build/

# Install to PATH
make install
```

**Configuration errors:**
```bash
# Reset config
shell-ai setup

# Test providers
shell-ai test
```

**tmux integration issues:**
```bash
# Check tmux
echo $TMUX

# Test pane selection
shell-ai --no-panes ask "test"
```

**Context gathering problems:**
```bash
# Show current context
shell-ai interactive
/context

# Disable problematic sources
shell-ai --no-history ask "test"
```

### Debug Mode
```bash
# Verbose logging
SHELL_AI_DEBUG=1 shell-ai interactive

# Test individual components
go test -v ./pkg/...
```

## 🔮 Roadmap

- [ ] **Streaming Responses**: Real-time AI response streaming
- [ ] **Additional Providers**: Anthropic, Google, Ollama implementations
- [ ] **Plugin System**: Custom provider plugins
- [ ] **Web UI**: Browser-based interface
- [ ] **History Search**: Semantic conversation search
- [ ] **Team Features**: Shared conversation contexts

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Make changes and add tests
4. Run quality checks (`make fmt lint test`)
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open Pull Request

### Development Guidelines
- Write tests for new functionality
- Follow Go conventions and idioms
- Update documentation
- Ensure backward compatibility

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

## 🙏 Acknowledgments

- Original shell-ai project for inspiration and architecture
- tmux-selector-go for pane selection implementation
- Charm Bracelet for excellent terminal UI libraries
- Go community for robust tooling and libraries

---

**Happy AI-enhanced shell scripting! 🤖✨**
