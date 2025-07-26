#!/bin/bash

# Shell AI Integration Installation Script
# This script installs the shell AI integration on non-Docker systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.config/shell-ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=== Shell AI Integration Installer ===${NC}"
echo

# Function to detect user's shell
detect_shell() {
    local user_shell=$(basename "$SHELL")
    echo "$user_shell"
}

# Function to compare version strings
version_compare() {
    local version1=$1
    local version2=$2
    
    # Convert versions to comparable format (e.g., "3.5a" -> "3.5.1")
    local v1=$(echo "$version1" | sed 's/a$/\.1/' | sed 's/b$/\.2/' | sed 's/c$/\.3/')
    local v2=$(echo "$version2" | sed 's/a$/\.1/' | sed 's/b$/\.2/' | sed 's/c$/\.3/')
    
    # Compare versions using sort
    if [[ $(printf '%s\n' "$v2" "$v1" | sort -V | head -n1) == "$v2" ]]; then
        return 0  # version1 >= version2
    else
        return 1  # version1 < version2
    fi
}

# Check tmux version for split-window bug
check_tmux_version() {
    if command -v tmux >/dev/null 2>&1; then
        local tmux_version=$(tmux -V | cut -d' ' -f2)
        echo -e "${BLUE}Found tmux version: $tmux_version${NC}"
        
        if ! version_compare "$tmux_version" "3.5"; then
            echo -e "${YELLOW}⚠ WARNING: tmux version $tmux_version detected${NC}"
            echo -e "${YELLOW}  Versions older than 3.5 have a bug with 'split-window -p' percentage splits${NC}"
            echo -e "${YELLOW}  Some tmux AI integration features may not work correctly${NC}"
            echo -e "${YELLOW}  Consider upgrading to tmux 3.5+ or building from source${NC}"
            echo
        else
            echo -e "${GREEN}✓ tmux version is sufficient (>= 3.5)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ tmux not found - install tmux for full integration${NC}"
        echo -e "${YELLOW}  Recommended: tmux 3.5+ to avoid split-window bugs${NC}"
    fi
}

# Check dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    local missing_deps=()
    
    # Check for required commands
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    
    # Check for supported shells
    local shell_found=false
    if command -v bash >/dev/null 2>&1; then
        shell_found=true
        echo -e "${GREEN}✓ bash found${NC}"
    fi
    if command -v zsh >/dev/null 2>&1; then
        shell_found=true
        echo -e "${GREEN}✓ zsh found${NC}"
    fi
    
    if [[ "$shell_found" == false ]]; then
        missing_deps+=("bash or zsh")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required dependencies: ${missing_deps[*]}${NC}"
        echo "Please install the missing dependencies and run the installer again."
        
        # Provide installation hints for common systems
        if command -v apt-get >/dev/null 2>&1; then
            echo -e "${YELLOW}On Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}${NC}"
        elif command -v yum >/dev/null 2>&1; then
            echo -e "${YELLOW}On RHEL/CentOS: sudo yum install ${missing_deps[*]}${NC}"
        elif command -v brew >/dev/null 2>&1; then
            echo -e "${YELLOW}On macOS: brew install ${missing_deps[*]}${NC}"
        fi
        
        exit 1
    fi
    
    echo -e "${GREEN}✓ All dependencies satisfied${NC}"
    
    # Check tmux version
    check_tmux_version
}

# Create installation directory
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}✓ Directory created: $INSTALL_DIR${NC}"
}

# Install scripts
install_scripts() {
    echo -e "${YELLOW}Installing scripts...${NC}"
    
    local scripts=(
        "ai-setup.sh"
        "ai-shell.sh"
        "ai-copy.sh"
        "tmux-ai-pane.sh"
        "welcome.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/scripts/$script" ]]; then
            cp "$SCRIPT_DIR/scripts/$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            echo -e "${GREEN}✓ Installed: $script${NC}"
        else
            echo -e "${RED}✗ Script not found: $script${NC}"
            exit 1
        fi
    done
    
    # Install Go binary if available
    local go_binary="$SCRIPT_DIR/tmux-selector-go/tmux-selector"
    if [[ -f "$go_binary" ]]; then
        cp "$go_binary" "$INSTALL_DIR/tmux-selector-go"
        chmod +x "$INSTALL_DIR/tmux-selector-go"
        echo -e "${GREEN}✓ Installed: tmux-selector (Go binary)${NC}"
    else
        echo -e "${YELLOW}⚠ tmux-selector Go binary not found - run 'make go-binary' to build it${NC}"
        echo -e "${YELLOW}  ai-copy.sh will still work but may be slower${NC}"
    fi
}

# Install provider files
install_providers() {
    echo -e "${YELLOW}Installing AI providers...${NC}"
    
    # Create providers directory
    mkdir -p "$INSTALL_DIR/providers"
    
    # Copy all provider files
    if [[ -d "$SCRIPT_DIR/providers" ]]; then
        local provider_count=0
        for provider_file in "$SCRIPT_DIR/providers"/*.sh; do
            if [[ -f "$provider_file" ]]; then
                cp "$provider_file" "$INSTALL_DIR/providers/"
                chmod +x "$INSTALL_DIR/providers/$(basename "$provider_file")"
                echo -e "${GREEN}✓ Installed provider: $(basename "$provider_file")${NC}"
                ((++provider_count))
            fi
        done
        
        if [[ $provider_count -eq 0 ]]; then
            echo -e "${YELLOW}⚠ No provider files found in $SCRIPT_DIR/providers${NC}"
        else
            echo -e "${GREEN}✓ Installed $provider_count AI providers${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Providers directory not found: $SCRIPT_DIR/providers${NC}"
    fi
}

# Install configurations
install_config() {
    echo -e "${YELLOW}Installing configuration files...${NC}"
    
    # Install tmux config
    install_tmux_config
    
    # Install AI config template
    if [[ -f "$SCRIPT_DIR/config/ai-config.json" ]] && [[ ! -f "$INSTALL_DIR/config.json" ]]; then
        cp "$SCRIPT_DIR/config/ai-config.json" "$INSTALL_DIR/config.json"
        echo -e "${GREEN}✓ AI configuration template installed${NC}"
        echo -e "${YELLOW}  Edit $INSTALL_DIR/config.json to add your API keys${NC}"
    fi
}

# Install tmux configuration with smart handling of existing configs
install_tmux_config() {
    if [[ ! -f "$SCRIPT_DIR/config/tmux.conf" ]]; then
        echo -e "${YELLOW}⚠ tmux.conf not found in source, skipping${NC}"
        return
    fi
    
    # Check for Oh my tmux! configuration paths
    local tmux_conf_path="$HOME/.tmux.conf"
    if [[ -f "$HOME/.tmux.conf.local" ]]; then
        tmux_conf_path="$HOME/.tmux.conf.local"
        echo -e "${BLUE}Detected Oh my tmux! configuration: ~/.tmux.conf.local${NC}"
    elif [[ -f "$HOME/.config/tmux/tmux.conf.local" ]]; then
        tmux_conf_path="$HOME/.config/tmux/tmux.conf.local"
        echo -e "${BLUE}Detected Oh my tmux! configuration: ~/.config/tmux/tmux.conf.local${NC}"
    fi
    
    local ai_marker="# Shell AI Integration - Auto-generated"
    
    # Check if tmux.conf already exists
    if [[ -f "$tmux_conf_path" ]]; then
        # Check if Shell AI integration is already installed
        if grep -q "$ai_marker" "$tmux_conf_path" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Shell AI tmux integration already installed${NC}"
            return
        fi
        
        echo -e "${YELLOW}Existing tmux.conf detected, appending Shell AI integration...${NC}"
        
        # Extract AI-specific configuration from source tmux.conf
        # This is more reliable than trying to escape strings in heredoc
        {
            echo ""
            echo "$ai_marker"
            # Extract lines from "# AI Integration keybindings" to end of file
            sed -n '/^# AI Integration keybindings/,$p' "$SCRIPT_DIR/config/tmux.conf"
        } >> "$tmux_conf_path"
        
        echo -e "${GREEN}✓ Shell AI tmux integration appended to existing configuration${NC}"
    else
        # No existing tmux.conf, install the full configuration
        cp "$SCRIPT_DIR/config/tmux.conf" "$tmux_conf_path"
        echo -e "${GREEN}✓ tmux configuration installed${NC}"
    fi
}

# Install shell integration
install_shell_integration() {
    local user_shell=$(detect_shell)
    echo -e "${YELLOW}Installing $user_shell integration...${NC}"
    
    case "$user_shell" in
        "bash")
            install_bash_integration
            ;;
        "zsh")
            install_zsh_integration
            ;;
        *)
            echo -e "${YELLOW}⚠ Unsupported shell: $user_shell${NC}"
            echo -e "${YELLOW}  Attempting bash integration as fallback${NC}"
            install_bash_integration
            ;;
    esac
}

# Install bash integration
install_bash_integration() {
    # Check if already installed
    if grep -q "# Shell AI Integration" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Bash integration already installed${NC}"
        return
    fi
    
    # Add to bashrc
    cat >> "$HOME/.bashrc" << 'EOF'

# Shell AI Integration
if [[ -f ~/.config/shell-ai/bashrc-ai.sh ]]; then
    source ~/.config/shell-ai/bashrc-ai.sh
fi

# Show welcome message on login (comment out if not desired)
if [[ -f ~/.config/shell-ai/welcome.sh ]]; then
    ~/.config/shell-ai/welcome.sh
fi
EOF
    
    # Copy bash integration script
    if [[ -f "$SCRIPT_DIR/config/bashrc-ai.sh" ]]; then
        cp "$SCRIPT_DIR/config/bashrc-ai.sh" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ Bash integration installed${NC}"
    fi
}

# Install zsh integration
install_zsh_integration() {
    # Check if already installed
    if grep -q "# Shell AI Integration" "$HOME/.zshrc" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Zsh integration already installed${NC}"
        return
    fi
    
    # Add to zshrc
    cat >> "$HOME/.zshrc" << 'EOF'

# Shell AI Integration
if [[ -f ~/.config/shell-ai/zshrc-ai.sh ]]; then
    source ~/.config/shell-ai/zshrc-ai.sh
fi

# Show welcome message on login (comment out if not desired)
if [[ -f ~/.config/shell-ai/welcome.sh ]]; then
    ~/.config/shell-ai/welcome.sh
fi
EOF
    
    # Copy zsh integration script
    if [[ -f "$SCRIPT_DIR/config/zshrc-ai.sh" ]]; then
        cp "$SCRIPT_DIR/config/zshrc-ai.sh" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ Zsh integration installed${NC}"
    fi
}

# Install atuin (optional)
install_atuin() {
    if command -v atuin >/dev/null 2>&1; then
        echo -e "${GREEN}✓ atuin already installed${NC}"
        return
    fi
    
    echo -e "${YELLOW}Installing atuin for enhanced shell history...${NC}"
    read -p "Install atuin? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v curl >/dev/null 2>&1; then
            curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
            echo 'eval "$(atuin init bash)"' >> "$HOME/.bashrc"
            echo -e "${GREEN}✓ atuin installed${NC}"
        else
            echo -e "${RED}✗ curl not available for atuin installation${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping atuin installation${NC}"
    fi
}

# Main installation
main() {
    echo "This script will install Shell AI Integration to your system."
    echo "Installation directory: $INSTALL_DIR"
    echo
    read -p "Continue with installation? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    check_dependencies
    create_directories
    install_scripts
    install_providers
    install_config
    install_shell_integration
    install_atuin
    
    local user_shell=$(detect_shell)
    
    echo
    echo -e "${GREEN}=== Installation Complete! ===${NC}"
    echo -e "Configured for: ${BLUE}$user_shell${NC}"
    echo
    echo "Next steps:"
    if [[ "$user_shell" == "zsh" ]]; then
        echo "1. Reload your shell configuration: source ~/.zshrc"
    else
        echo "1. Reload your shell configuration: source ~/.bashrc"
    fi
    echo "2. Configure AI providers: ai-setup"
    echo "3. Test the integration: ai-test"
    echo
    echo "For tmux integration, restart tmux or run: tmux source-file ~/.tmux.conf"
    echo
    echo "Usage examples:"
    echo "  ai 'explain this command: ls -la'"
    echo "  @how do I find large files"
    echo "  ai-last  # explain last command"
    echo "  ai-fix   # fix last failed command"
    echo
    echo "Documentation: docs/USAGE.md"
}

main "$@" 