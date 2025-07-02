```
 ██████╗██╗  ██╗███████╗██╗     ██╗         █████╗ ██╗
██╔════╝██║  ██║██╔════╝██║     ██║        ██╔══██╗██║
███████╗███████║█████╗  ██║     ██║        ███████║██║
╚════██║██╔══██║██╔══╝  ██║     ██║        ██╔══██║██║
███████║██║  ██║███████╗███████╗███████╗   ██║  ██║██║
╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝   ╚═╝  ╚═╝╚═╝
```
<div align="center">

**🤖 AI-Enhanced Shell Environment 🤖**

*Seamlessly integrate multiple AI providers with your command-line workflow*

[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![AI](https://img.shields.io/badge/AI-Multi--Provider-blue?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![tmux](https://img.shields.io/badge/tmux-Integrated-red?style=for-the-badge&logo=tmux&logoColor=white)](https://github.com/tmux/tmux)

</div>

---

# Shell AI Integration

An AI-enhanced shell environment that seamlessly integrates multiple AI providers with your command-line workflow. Get intelligent assistance, command explanations, and context-aware suggestions directly in your terminal.

## 🚀 Features

- **Multi-Provider AI Support**: OpenAI, Anthropic, Google Gemini, and Ollama
- **Smart Context Capture**: Automatically includes shell history (via atuin) and tmux pane content
- **Two Prompt Methods**: 
  - `@` prefix for quick queries: `@how do I find large files`
  - Dedicated tmux pane for AI interactions
- **Response Management**: AI output can be extracted and executed safely
- **Enhanced History**: Integrates with atuin for superior command history
- **Docker Development Environment**: Pre-configured development container

## 📋 Quick Start

### Option 1: Using Docker (Recommended for Development)

1. **Clone and Build**:
   ```bash
   git clone <repository-url>
   cd shell-ai
   docker build -t shell-ai .
   ```

2. **Run Docker container with Configuration (useful when doing development on this project)**:
   ```bash
   # With persistent AI configuration
   docker run -it -v $(pwd)/config/ai-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai
   
   # Or run and configure interactively
   docker run -it shell-ai
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

2. **Run Installer**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Reload Shell**:
   ```bash
   source ~/.bashrc
   ```

4. **Configure AI Provider**:
   ```bash
   ai-setup
   ```

## 🐳 Docker Development Environment

### Building the Image

```bash
docker build -t shell-ai .
```

### Running with Configuration

To avoid reconfiguring AI providers each time, mount your configuration file:

```bash
# Create your config file
cp config/ai-config.json my-ai-config.json
# Edit my-ai-config.json with your API keys

# Run with mounted config
docker run -it -v $(pwd)/my-ai-config.json:/home/shelluser/.config/shell-ai/config.json shell-ai
```

### Persistent Development Setup

For development work, you can mount the entire project directory:

```bash
docker run -it \
  -v $(pwd):/workspace \
  -v $(pwd)/my-ai-config.json:/home/shelluser/.config/shell-ai/config.json \
  shell-ai
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

## 📁 Project Structure

```
shell-ai/
├── Dockerfile              # Docker development environment
├── README.md               # This file
├── install.sh             # Installation script for non-Docker
├── scripts/               # AI integration scripts
│   ├── ai-setup.sh        # Provider configuration
│   ├── ai-shell.sh        # Main AI integration
│   ├── ai-copy.sh         # Response management
│   ├── tmux-ai-pane.sh    # tmux AI pane helper
│   └── welcome.sh         # Welcome message
├── config/                # Configuration files
│   ├── tmux.conf          # tmux configuration
│   ├── bashrc-ai.sh       # Bash AI integration
│   └── ai-config.json     # AI provider template
└── docs/                  # Additional documentation
    └── USAGE.md           # Detailed usage guide
```

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

```bash
# Build and test
docker build -t shell-ai-dev .
docker run -it -v $(pwd):/workspace shell-ai-dev

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