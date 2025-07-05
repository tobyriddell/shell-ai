# Shell AI Integration

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

### Option 1: Using Docker (Recommended for Development)

**Using the Makefile (Recommended):**
1. **Clone and Build**:
   ```bash
   git clone <repository-url>
   cd shell-ai
   
   # Build and run bash environment
   make run-bash
   
   # Build and run zsh environment
   make run-zsh
   
   # Build both images
   make all
   ```

2. **Development workflow**:
   ```bash
   # Run with project mounted for development
   make dev-bash    # or make dev-zsh
   
   # Run with configuration
   make run-bash-config    # or make run-zsh-config
   
   # Run tests
   make test
   
   # See all available targets
   make help
   ```

**Manual Docker commands:**
1. **For bash users**:
   ```bash
   docker build -f Dockerfile.bash -t shell-ai-bash .
   docker run -it -v $(pwd)/config/ai-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai-bash
   ```

2. **For zsh users**:
   ```bash
   # With persistent AI configuration
   docker run -it -v $(pwd)/config/ai-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai-zsh
   
   # Or run and configure interactively
   docker run -it shell-ai-zsh
   ```

3. **Configure AI Provider**:
   ```bash
   ai-setup  # Interactive setup menu
   ```

### Option 2: Direct Installation

1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd shell-ai
   ```

2. **Run Installer** (auto-detects bash/zsh):
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Reload Shell**:
   ```bash
   source ~/.bashrc  # for bash
   # or
   source ~/.zshrc   # for zsh
   ```

4. **Configure AI Provider**:
   ```bash
   ai-setup
   ```

## 🐳 Docker Development Environment

### Building the Images

**Using Makefile (Recommended):**
```bash
# Build both images
make all

# Build specific image
make bash    # Build bash image
make zsh     # Build zsh image

# Show available targets
make help
```

**Manual Docker commands:**
```bash
# For bash
docker build -f Dockerfile.bash -t shell-ai-bash .

# For zsh
docker build -f Dockerfile.zsh -t shell-ai-zsh .
```

### Running with Configuration

**Using Makefile:**
```bash
# Run with example configuration pre-mounted
make run-bash-config    # For bash
make run-zsh-config     # For zsh
```

**Manual approach:**
```bash
# Create your config file
cp config/ai-config.json my-ai-config.json
# Edit my-ai-config.json with your API keys

# Run with mounted config
docker run -it -v $(pwd)/my-ai-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai-bash
```

### Development Setup

**Using Makefile:**
```bash
# Development environment with project mounted
make dev-bash    # For bash development
make dev-zsh     # For zsh development

# Debug containers
make shell-bash  # Open bash shell for debugging
make shell-zsh   # Open zsh shell for debugging
```

**Manual approach:**
```bash
docker run -it \
  -v $(pwd):/workspace \
  -v $(pwd)/config/ai-config.example.json:/home/shelluser/.config/shell-ai/config.json \
  -w /workspace \
  shell-ai-bash
```

## 🔧 Configuration

### AI Provider Configuration

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

### Command Line Integration

```bash
# Quick AI queries with @ prefix
@explain the ps command
@fix this error: permission denied
@how do I find files larger than 1GB

# Direct AI commands
ai "help me write a bash script to backup files"
ai-last    # Explain the last command
ai-fix     # Fix the last failed command
ai-here    # Ask about current directory contents
```

### tmux Integration

**Keybindings** (prefix: Ctrl-A):

![NOTE] the use of capital letters

- `Ctrl-A + A`: Toggle AI input pane
- `Ctrl-A + I`: Quick AI query prompt
- `Ctrl-A + C`: AI response manager  
- `Ctrl-A + T`: Test AI providers
- `Ctrl-A + X`: Show AI context

**Workflow**:
1. Press `Ctrl-A + A` to create AI input pane
2. Type AI queries in the dedicated pane
3. Responses appear and can be copied to main pane
4. Use `ai-copy` to manage and execute AI suggestions

### Response Management

```bash
ai-copy    # Interactive menu to:
           # 1. View full AI response
           # 2. Extract and execute commands
           # 3. Send to specific tmux panes
           # 4. Copy commands to clipboard
```

## 🧪 Testing

The project includes comprehensive unit tests covering all major functionality. Tests use mocking to avoid actual AI API calls and external dependencies.

**For developers**: See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed testing instructions, development setup, and contribution guidelines.

### Quick Test Run

```bash
# Run all tests (Linux/macOS)
bash tests/test_runner.sh

# Run tests in Docker (Cross-platform)
docker build -t shell-ai-test .
docker run --rm shell-ai-test bash tests/test_runner.sh

# Run tests on Windows (WSL2/Git Bash)
cd /mnt/c/path/to/shell-ai  # WSL2
# or
cd /c/path/to/shell-ai      # Git Bash
bash tests/test_runner.sh
```

## 📁 Project Structure

```
shell-ai/
├── Dockerfile.bash         # Docker development environment (bash)
├── Dockerfile.zsh          # Docker development environment (zsh)
├── Makefile               # Build automation for Docker images
├── README.md               # This file
├── install.sh             # Installation script (auto-detects shell)
├── tests/                 # Unit tests for both bash and zsh
│   ├── test_runner.sh     # Test runner for both shells
│   ├── test_command_extraction.sh
│   ├── test_ai_shell.sh
│   ├── test_config_management.sh
│   ├── test_tmux_integration.sh
│   └── test_prefix_handling.sh
├── scripts/               # AI integration scripts
│   ├── ai-setup.sh        # Provider configuration
│   ├── ai-shell.sh        # Main AI integration (shell-agnostic)
│   ├── ai-copy.sh         # Response management
│   ├── tmux-ai-pane.sh    # tmux AI pane helper
│   └── welcome.sh         # Welcome message
├── config/                # Configuration files
│   ├── tmux.conf          # tmux configuration
│   ├── bashrc-ai.sh       # Bash integration (@ prefix)
│   └── ai-config.example.json  # Example configuration
├── tests/                 # Unit test suite
│   ├── test_runner.sh     # Main test runner
│   ├── test_command_extraction.sh  # Command parsing tests
│   ├── test_ai_shell.sh   # AI integration tests
│   ├── test_config_management.sh   # Configuration tests
│   ├── test_tmux_integration.sh    # tmux functionality tests
│   └── test_prefix_handling.sh     # @ prefix tests
└── docs/                  # Additional documentation
    └── USAGE.md           # Detailed usage guide

```

## 🧪 Testing

The project includes comprehensive unit tests for both bash and zsh shells:

### Run All Tests

```bash
# Run tests for both shells
./tests/test_runner.sh
```

### Docker Testing

**Using Makefile:**
```bash
# Run tests for both shells
make test

# Test specific shell
make test-bash
make test-zsh
```

**Manual commands:**
```bash
# Test zsh integration
docker build -f Dockerfile.zsh -t shell-ai-zsh .
docker run shell-ai-zsh ./tests/test_runner.sh

# Test bash integration  
docker build -f Dockerfile.bash -t shell-ai-bash .
docker run shell-ai-bash ./tests/test_runner.sh
```

### Test Coverage

Tests verify:
- **Command Extraction**: `@` prefix parsing and argument handling
- **AI Shell Functions**: Help display, context building, prompt processing
- **Configuration Management**: JSON parsing, provider settings, validation
- **tmux Integration**: Pane capture, split commands, key bindings
- **Shell-Specific Features**: History handling differences between bash/zsh

### Prerequisites for Native Testing

- bash and zsh installed
- jq for JSON processing
- curl for API testing (mocked in tests)

## 🔧 Dependencies

### Required
- `bash` 4.0+
- `curl`
- `jq`
- `tmux` 3.5+ (for tmux integration)

### Optional
- `atuin` (enhanced shell history)
- Docker (for development environment)

### Installation Commands

**Ubuntu/Debian**:
```bash
sudo apt-get install bash curl jq tmux
```

**macOS**:
```bash
brew install bash curl jq tmux
```

**RHEL/CentOS**:
```bash
sudo yum install bash curl jq tmux
```

## 🚀 Advanced Usage

### Custom Configuration

Modify behavior by editing configuration files:

- `~/.config/shell-ai/config.json` - AI provider settings
- `~/.tmux.conf` - tmux keybindings and behavior
- `~/.config/shell-ai/bashrc-ai.sh` - Shell integration functions

### API Rate Limiting

The integration respects API rate limits. For heavy usage:
- Use Ollama for local inference
- Configure multiple providers for fallback
- Adjust context size with `--history-lines` and `--pane-lines`

### Security Considerations

- API keys are stored in `~/.config/shell-ai/config.json`
- Set appropriate file permissions: `chmod 600 ~/.config/shell-ai/config.json`
- In Docker, mount config file with read-only permissions
- Consider using environment variables for API keys in production

## 🐛 Troubleshooting

### Common Issues

1. **AI not responding**:
   ```bash
   ai-test  # Test all configured providers
   ```

2. **Commands not found**:
   ```bash
   source ~/.bashrc  # Reload shell configuration
   ```

3. **tmux keybindings not working**:
   ```bash
   tmux source-file ~/.tmux.conf  # Reload tmux config
   ```

4. **Permission errors**:
   ```bash
   chmod +x ~/.config/shell-ai/*.sh  # Fix script permissions
   ```

### Debug Mode

```bash
ai --context  # Show what context is sent to AI
ai-copy      # Interactive response management
```

### Getting Help

```bash
ai --help           # Show AI integration help
ai-setup            # Reconfigure providers
tmux list-keys      # Show tmux keybindings
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test in Docker environment
4. Submit a pull request

### Development Workflow

**Using Makefile:**
```bash
# Quick development cycle
make dev-bash    # Start development container
make test        # Run all tests
make clean       # Clean up images

# CI/CD pipeline
make ci          # Full build and test pipeline

# Utility commands
make images      # List built images
make size        # Show image sizes
make check       # Verify project structure
```

**Manual workflow:**
```bash
# Build and test
docker build -f Dockerfile.bash -t shell-ai-bash .
docker run -it -v $(pwd):/workspace shell-ai-bash

# Test installation script
./install.sh --dry-run
```

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
