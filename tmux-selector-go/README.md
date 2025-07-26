# tmux-selector (Go Implementation)

A high-performance Go implementation of the tmux pane selector, providing the same functionality as the Rust version with native Go performance and cross-platform compatibility.

## Features

- **Fast Interactive Selection**: Native terminal UI using tcell library
- **Smart Defaults**: Automatically selects the most recently used pane
- **Cross-Platform**: Works on both macOS and Linux  
- **Multiple Output Formats**: Plain text or JSON output
- **Rich Navigation**: Arrow keys, WASD, HJKL (vim-style) support
- **Auto-Select Mode**: Non-interactive mode for scripting

## Usage

### Interactive Mode (Default)

```bash
tmux-selector
```

Navigate with:
- **Arrow keys** (↑↓←→) or **WASD** or **HJKL** (vim-style)
- **Enter** to select
- **q**, **Q**, or **Esc** to cancel

### Auto-Select Mode

```bash
tmux-selector --auto
```

Automatically selects the most recently used pane without user interaction.

### JSON Output

```bash
tmux-selector --format json
```

Returns detailed pane information in JSON format:

```json
{
  "session_name": "main",
  "window_index": "0", 
  "pane_index": "1",
  "pane_title": "bash",
  "last_used": 1641234567,
  "is_active": false,
  "full_id": "main:0.1"
}
```

## Building

### Prerequisites

- Go 1.21 or later

### Build Commands

```bash
# Build for development
go build -o tmux-selector

# Build optimized release binary
go build -ldflags="-s -w" -o tmux-selector

# Cross-compile for different platforms
GOOS=linux GOARCH=amd64 go build -o tmux-selector-linux
GOOS=darwin GOARCH=amd64 go build -o tmux-selector-darwin
GOOS=darwin GOARCH=arm64 go build -o tmux-selector-darwin-arm64
```

### Dependencies

- `github.com/gdamore/tcell/v2`: Cross-platform terminal handling
- `github.com/spf13/cobra`: Command-line interface library

## Performance

The Go implementation provides excellent performance characteristics:

- **Fast startup**: Quick cold start time
- **Responsive UI**: Low input latency
- **Cross-platform**: Single binary for multiple architectures
- **Efficient**: Good performance for interactive terminal applications

## Integration with Shell AI

This Go implementation is a drop-in replacement for the Rust version in the Shell AI Integration project. The ai-copy.sh script will automatically detect and use whichever binary is available.

## Error Handling

- **Not in tmux**: Exits with error message and code 1
- **No panes found**: Exits with error message and code 1  
- **Selection cancelled**: Exits with code 1
- **Invalid arguments**: Shows help and exits with code 1

## Platform Support

- **Linux**: All distributions with glibc 2.17+ (CentOS 7+, Ubuntu 14.04+)
- **macOS**: 10.15+ (both Intel and Apple Silicon)
- **Windows**: Windows 10+ with WSL support
- **Terminal**: Any terminal that supports ANSI escape sequences

## Comparison with Rust Version

| Feature | Go Implementation | Rust Implementation |
|---------|------------------|-------------------|
| Startup Time | Fast | Generally faster |
| Memory Usage | Higher | Lower |
| Binary Size | Larger | Smaller |
| Cross-compilation | Excellent | Excellent |
| Dependencies | 2 external | 4 external |
| Build Time | Faster | Longer |

Both implementations provide the same user experience and functionality. Run `make binaries` to build both and benchmark them in your environment. 