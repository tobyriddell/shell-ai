#!/bin/bash

# Comprehensive Installation Test Suite
# Tests install.sh with various combinations of shell configs, tmux configs, and atuin

# Note: We don't use set -e here because we want to handle test failures gracefully

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_HOME="/tmp/shell-ai-test-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"

# Debug information
echo -e "${BLUE}Debug: SCRIPT_DIR=$SCRIPT_DIR${NC}"
echo -e "${BLUE}Debug: PROJECT_ROOT=$PROJECT_ROOT${NC}"
echo -e "${BLUE}Debug: INSTALL_SCRIPT=$INSTALL_SCRIPT${NC}"
echo -e "${BLUE}Debug: Install script exists: $(test -f "$INSTALL_SCRIPT" && echo "YES" || echo "NO")${NC}"
echo -e "${BLUE}Debug: Scripts directory exists: $(test -d "$PROJECT_ROOT/scripts" && echo "YES" || echo "NO")${NC}"
echo -e "${BLUE}Debug: Config directory exists: $(test -d "$PROJECT_ROOT/config" && echo "YES" || echo "NO")${NC}"
echo -e "${BLUE}Debug: tmux.conf exists: $(test -f "$PROJECT_ROOT/config/tmux.conf" && echo "YES" || echo "NO")${NC}"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test results storage
declare -a FAILED_TEST_NAMES=()

echo -e "${BLUE}=== Shell AI Installation Test Suite ===${NC}"
echo "Testing install.sh with various shell/tmux/atuin configurations"
echo "Test environment: $TEST_HOME"
echo

# Initialize test environment
init_test_env() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Clean up any existing test directory
    if [[ -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
    fi
    
    # Create test home directory
    mkdir -p "$TEST_HOME"
    cd "$TEST_HOME"
    
    # Create necessary directories
    mkdir -p "$TEST_HOME/.config/tmux"
    mkdir -p "$TEST_HOME/.config/shell-ai"
    
    # Set HOME for this test session
    export HOME="$TEST_HOME"
    
    echo -e "${GREEN}✓ Test environment initialized${NC}"
}

# Clean up test environment
cleanup_test_env() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    cd /
    if [[ -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
    fi
    echo -e "${GREEN}✓ Test environment cleaned up${NC}"
}

# Test helper functions
assert_file_exists() {
    local file="$1"
    local message="$2"
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "${RED}✗ $message - File not found: $file${NC}"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "${RED}✗ $message - Pattern not found in $file${NC}"
        return 1
    fi
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    
    if [[ ! -f "$file" ]] || ! grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓ $message${NC}"
        return 0
    else
        echo -e "${RED}✗ $message - Pattern found in $file${NC}"
        return 1
    fi
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "${BLUE}Running test: $test_name${NC}"
    ((TOTAL_TESTS++))
    
    # Initialize clean test environment for each test
    echo -e "${YELLOW}  Initializing test environment...${NC}"
    if ! init_test_env; then
        echo -e "${RED}✗ FAILED: $test_name (environment setup failed)${NC}"
        ((FAILED_TESTS++))
        FAILED_TEST_NAMES+=("$test_name")
        cleanup_test_env
        echo
        return 1
    fi
    
    # Run the test with error capturing
    echo -e "${YELLOW}  Running test function: $test_function${NC}"
    local test_output
    local test_exit_code
    
    # Capture output and exit code
    if [[ -n "${SHELL_AI_TEST_DEBUG:-}" ]]; then
        # In debug mode, show output in real-time
        if $test_function; then
            test_exit_code=0
        else
            test_exit_code=$?
        fi
    else
        # In normal mode, capture output
        test_output=$($test_function 2>&1)
        test_exit_code=$?
    fi
    
    # Report results
    if [[ $test_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ PASSED: $test_name${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ FAILED: $test_name (exit code: $test_exit_code)${NC}"
        if [[ -n "$test_output" && -z "${SHELL_AI_TEST_DEBUG:-}" ]]; then
            echo -e "${YELLOW}  Error output:${NC}"
            echo "$test_output" | sed 's/^/    /'
        fi
        ((FAILED_TESTS++))
        FAILED_TEST_NAMES+=("$test_name")
    fi
    
    # Clean up after test
    echo -e "${YELLOW}  Cleaning up test environment...${NC}"
    cleanup_test_env
    echo
    
    return $test_exit_code
}

# Test results summary
print_test_summary() {
    echo -e "${BLUE}=== Test Results Summary ===${NC}"
    echo -e "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    if [[ ${#FAILED_TEST_NAMES[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed tests:${NC}"
        for test_name in "${FAILED_TEST_NAMES[@]}"; do
            echo -e "  - $test_name"
        done
    fi
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Signal handler for cleanup
trap cleanup_test_env EXIT

# Environment setup functions
setup_simple_bash() {
    echo -e "${YELLOW}Setting up simple bash configuration...${NC}"
    
    # Create basic .bashrc
    cat > "$HOME/.bashrc" << 'EOF'
# Simple bash configuration
export PS1='\u@\h:\w\$ '
export PATH=/usr/local/bin:/usr/bin:/bin
source ~/.profile 2>/dev/null || true
EOF
    
    # Create basic .bash_profile
    cat > "$HOME/.bash_profile" << 'EOF'
# Simple bash profile
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
EOF
    
    echo -e "${GREEN}✓ Simple bash configuration created${NC}"
}

setup_oh_my_bash() {
    echo -e "${YELLOW}Setting up Oh My Bash configuration...${NC}"
    
    # Create .bashrc that simulates Oh My Bash
    cat > "$HOME/.bashrc" << 'EOF'
# Oh My Bash configuration
export OSH="$HOME/.oh-my-bash"
export OSH_THEME="powerline"

# Oh My Bash plugins
plugins=(
    git
    bashmarks
    battery
    brew
    docker
    docker-compose
    history
    npm
    python
    rbenv
    ssh
    sudo
    tmux
)

# Load Oh My Bash
source "$OSH/oh-my-bash.sh"

# User configuration
export PATH=/usr/local/bin:/usr/bin:/bin
EOF
    
    # Create simulated Oh My Bash directory structure
    mkdir -p "$HOME/.oh-my-bash"
    
    # Create a mock oh-my-bash.sh file
    cat > "$HOME/.oh-my-bash/oh-my-bash.sh" << 'EOF'
#!/bin/bash
# Mock Oh My Bash loader
echo "Oh My Bash loaded"
EOF
    
    echo -e "${GREEN}✓ Oh My Bash configuration created${NC}"
}

setup_simple_zsh() {
    echo -e "${YELLOW}Setting up simple zsh configuration...${NC}"
    
    # Create basic .zshrc
    cat > "$HOME/.zshrc" << 'EOF'
# Simple zsh configuration
export PS1='%n@%m:%~%# '
export PATH=/usr/local/bin:/usr/bin:/bin
autoload -U compinit
compinit
EOF
    
    # Create basic .zprofile
    cat > "$HOME/.zprofile" << 'EOF'
# Simple zsh profile
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi
EOF
    
    echo -e "${GREEN}✓ Simple zsh configuration created${NC}"
}

setup_oh_my_zsh() {
    echo -e "${YELLOW}Setting up Oh My Zsh configuration...${NC}"
    
    # Create .zshrc that simulates Oh My Zsh
    cat > "$HOME/.zshrc" << 'EOF'
# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Oh My Zsh plugins
plugins=(
    git
    docker
    docker-compose
    history
    npm
    python
    tmux
    z
)

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# User configuration
export PATH=/usr/local/bin:/usr/bin:/bin
EOF
    
    # Create simulated Oh My Zsh directory structure
    mkdir -p "$HOME/.oh-my-zsh"
    
    # Create a mock oh-my-zsh.sh file
    cat > "$HOME/.oh-my-zsh/oh-my-zsh.sh" << 'EOF'
#!/bin/zsh
# Mock Oh My Zsh loader
echo "Oh My Zsh loaded"
EOF
    
    echo -e "${GREEN}✓ Oh My Zsh configuration created${NC}"
}

setup_simple_tmux() {
    echo -e "${YELLOW}Setting up simple tmux configuration...${NC}"
    
    # Create basic .tmux.conf
    cat > "$HOME/.tmux.conf" << 'EOF'
# Simple tmux configuration
set -g prefix C-b
bind-key C-b send-prefix
set -g mouse on
set -g history-limit 10000

# Key bindings
bind r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind | split-window -h
bind - split-window -v
EOF
    
    echo -e "${GREEN}✓ Simple tmux configuration created${NC}"
}

setup_oh_my_tmux() {
    echo -e "${YELLOW}Setting up Oh My Tmux configuration...${NC}"
    
    # Create main .tmux.conf for Oh My Tmux
    cat > "$HOME/.tmux.conf" << 'EOF'
# Oh My Tmux configuration
# This is the main tmux configuration file
set -g default-terminal "screen-256color"
set -g history-limit 20000
set -g mouse on

# Oh My Tmux theme and settings
set -g status-bg colour235
set -g status-fg colour136
set -g status-left-length 20
set -g status-right-length 150

# Source local configuration
if-shell "[ -f ~/.tmux.conf.local ]" 'source ~/.tmux.conf.local'
EOF
    
    # Create Oh My Tmux local configuration file
    cat > "$HOME/.tmux.conf.local" << 'EOF'
# Oh My Tmux local configuration
# This is where user customizations go

# Custom key bindings
bind r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind | split-window -h
bind - split-window -v

# Custom appearance
set -g status-interval 5
set -g status-justify centre
EOF
    
    echo -e "${GREEN}✓ Oh My Tmux configuration created${NC}"
}

setup_oh_my_tmux_config_dir() {
    echo -e "${YELLOW}Setting up Oh My Tmux configuration in .config/tmux/...${NC}"
    
    # Create main .tmux.conf for Oh My Tmux
    cat > "$HOME/.tmux.conf" << 'EOF'
# Oh My Tmux configuration
# This is the main tmux configuration file
set -g default-terminal "screen-256color"
set -g history-limit 20000
set -g mouse on

# Oh My Tmux theme and settings
set -g status-bg colour235
set -g status-fg colour136
set -g status-left-length 20
set -g status-right-length 150

# Source local configuration from .config/tmux/
if-shell "[ -f ~/.config/tmux/tmux.conf.local ]" 'source ~/.config/tmux/tmux.conf.local'
EOF
    
    # Create Oh My Tmux local configuration file in .config/tmux/
    cat > "$HOME/.config/tmux/tmux.conf.local" << 'EOF'
# Oh My Tmux local configuration
# This is where user customizations go

# Custom key bindings
bind r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind | split-window -h
bind - split-window -v

# Custom appearance
set -g status-interval 5
set -g status-justify centre
EOF
    
    echo -e "${GREEN}✓ Oh My Tmux configuration in .config/tmux/ created${NC}"
}

setup_atuin() {
    echo -e "${YELLOW}Setting up atuin configuration...${NC}"
    
    # Create atuin config directory
    mkdir -p "$HOME/.config/atuin"
    
    # Create atuin config file
    cat > "$HOME/.config/atuin/config.toml" << 'EOF'
# Atuin configuration
auto_sync = true
sync_frequency = "5m"
search_mode = "fuzzy"
filter_mode = "global"
style = "compact"
EOF
    
    # Create mock atuin binary
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/atuin" << 'EOF'
#!/bin/bash
# Mock atuin binary
echo "Atuin mock - command: $*"
EOF
    chmod +x "$HOME/.local/bin/atuin"
    
    # Add to PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    echo -e "${GREEN}✓ Atuin configuration created${NC}"
}

# Verification functions
verify_shell_ai_scripts_installed() {
    echo -e "${YELLOW}Verifying Shell AI scripts are installed...${NC}"
    
    local scripts=(
        "ai-setup.sh"
        "ai-shell.sh"
        "ai-copy.sh"
        "tmux-ai-pane.sh"
        "welcome.sh"
    )
    
    local all_found=0
    for script in "${scripts[@]}"; do
        if ! assert_file_exists "$HOME/.config/shell-ai/$script" "Script $script installed"; then
            all_found=1
        fi
    done
    
    return $all_found
}

verify_bash_integration() {
    echo -e "${YELLOW}Verifying bash integration...${NC}"
    
    local result=0
    
    # Check that Shell AI integration was added to .bashrc
    if ! assert_file_contains "$HOME/.bashrc" "Shell AI Integration" "Shell AI integration added to .bashrc"; then
        result=1
    fi
    
    # Check that bashrc-ai.sh was installed
    if ! assert_file_exists "$HOME/.config/shell-ai/bashrc-ai.sh" "bashrc-ai.sh installed"; then
        result=1
    fi
    
    # Check that integration is properly sourced
    if ! assert_file_contains "$HOME/.bashrc" "source ~/.config/shell-ai/bashrc-ai.sh" "bashrc-ai.sh sourced in .bashrc"; then
        result=1
    fi
    
    return $result
}

verify_zsh_integration() {
    echo -e "${YELLOW}Verifying zsh integration...${NC}"
    
    local result=0
    
    # Check that Shell AI integration was added to .zshrc
    if ! assert_file_contains "$HOME/.zshrc" "Shell AI Integration" "Shell AI integration added to .zshrc"; then
        result=1
    fi
    
    # Check that zshrc-ai.sh was installed
    if ! assert_file_exists "$HOME/.config/shell-ai/zshrc-ai.sh" "zshrc-ai.sh installed"; then
        result=1
    fi
    
    # Check that integration is properly sourced
    if ! assert_file_contains "$HOME/.zshrc" "source ~/.config/shell-ai/zshrc-ai.sh" "zshrc-ai.sh sourced in .zshrc"; then
        result=1
    fi
    
    return $result
}

verify_tmux_integration() {
    local expected_config_path="$1"
    echo -e "${YELLOW}Verifying tmux integration in $expected_config_path...${NC}"
    
    local result=0
    
    # Check that Shell AI integration was added to the expected tmux config
    if ! assert_file_contains "$expected_config_path" "Shell AI Integration - Auto-generated" "Shell AI integration added to $expected_config_path"; then
        result=1
    fi
    
    # Check that AI Integration keybindings are present
    if ! assert_file_contains "$expected_config_path" "AI Integration keybindings" "AI keybindings added to $expected_config_path"; then
        result=1
    fi
    
    return $result
}

verify_no_duplicate_integration() {
    local file="$1"
    echo -e "${YELLOW}Verifying no duplicate integration in $file...${NC}"
    
    local count=$(grep -c "Shell AI Integration" "$file" 2>/dev/null || echo "0")
    
    if [[ "$count" -eq 1 ]]; then
        echo -e "${GREEN}✓ Single Shell AI integration found in $file${NC}"
        return 0
    else
        echo -e "${RED}✗ Found $count Shell AI integrations in $file (expected 1)${NC}"
        return 1
    fi
}

verify_existing_config_preserved() {
    local file="$1"
    local marker="$2"
    echo -e "${YELLOW}Verifying existing config preserved in $file...${NC}"
    
    if assert_file_contains "$file" "$marker" "Existing config marker preserved"; then
        return 0
    else
        return 1
    fi
}

# Mock installer runner (simulates user input)
run_installer() {
    local responses="$1"
    
    echo -e "${YELLOW}Running installer with responses: $responses${NC}"
    echo -e "${YELLOW}Install script: $INSTALL_SCRIPT${NC}"
    
    # Check if install script exists
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        echo -e "${RED}✗ Install script not found: $INSTALL_SCRIPT${NC}"
        return 1
    fi
    
    # Check if install script is executable
    if [[ ! -x "$INSTALL_SCRIPT" ]]; then
        echo -e "${YELLOW}Making install script executable...${NC}"
        chmod +x "$INSTALL_SCRIPT"
    fi
    
    # Create a temporary responses file
    local responses_file=$(mktemp)
    echo "$responses" > "$responses_file"
    
    # Run the installer with responses (from the project root directory)
    local current_dir=$(pwd)
    cd "$PROJECT_ROOT"
    
    if [[ -n "${SHELL_AI_TEST_DEBUG:-}" ]]; then
        # Debug mode: show all output
        "$INSTALL_SCRIPT" < "$responses_file"
        local exit_code=$?
    else
        # Normal mode: capture errors but silence normal output
        "$INSTALL_SCRIPT" < "$responses_file" >/dev/null 2>&1
        local exit_code=$?
    fi
    
    # Return to original directory
    cd "$current_dir"
    
    # Clean up
    rm -f "$responses_file"
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}✗ Installer failed with exit code $exit_code${NC}"
        echo -e "${YELLOW}Enable debug mode with: SHELL_AI_TEST_DEBUG=1${NC}"
        return $exit_code
    fi
    
    return 0
}

# BASH TESTS

# Test 1: Simple bash + simple tmux + no atuin
test_bash_simple_tmux_simple_no_atuin() {
    echo -e "${YELLOW}    Setting up simple bash configuration...${NC}"
    if ! setup_simple_bash; then
        echo -e "${RED}    Failed to setup simple bash${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}    Setting up simple tmux configuration...${NC}"
    if ! setup_simple_tmux; then
        echo -e "${RED}    Failed to setup simple tmux${NC}"
        return 1
    fi
    
    # Set SHELL environment variable for installer
    export SHELL="/bin/bash"
    echo -e "${YELLOW}    Set SHELL=/bin/bash${NC}"
    
    # Run installer with automated responses (continue installation, skip atuin)
    echo -e "${YELLOW}    Running installer...${NC}"
    if ! run_installer "y\nn"; then
        echo -e "${RED}    Installer failed${NC}"
        return 1
    fi
    
    # Verify installation
    echo -e "${YELLOW}    Verifying installation...${NC}"
    local verification_failed=0
    
    if ! verify_shell_ai_scripts_installed; then
        echo -e "${RED}    Shell AI scripts verification failed${NC}"
        verification_failed=1
    fi
    
    if ! verify_bash_integration; then
        echo -e "${RED}    Bash integration verification failed${NC}"
        verification_failed=1
    fi
    
    if ! verify_tmux_integration "$HOME/.tmux.conf"; then
        echo -e "${RED}    Tmux integration verification failed${NC}"
        verification_failed=1
    fi
    
    if ! verify_no_duplicate_integration "$HOME/.bashrc"; then
        echo -e "${RED}    Bash duplicate check failed${NC}"
        verification_failed=1
    fi
    
    if ! verify_no_duplicate_integration "$HOME/.tmux.conf"; then
        echo -e "${RED}    Tmux duplicate check failed${NC}"
        verification_failed=1
    fi
    
    if [[ "$verification_failed" -eq 1 ]]; then
        return 1
    fi
    
    echo -e "${GREEN}    All verifications passed${NC}"
    return 0
}

# Test 2: Simple bash + simple tmux + atuin
test_bash_simple_tmux_simple_with_atuin() {
    setup_simple_bash
    setup_simple_tmux
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf"
}

# Test 3: Simple bash + Oh My Tmux (.tmux.conf.local) + no atuin
test_bash_simple_tmux_oh_my_local_no_atuin() {
    setup_simple_bash
    setup_oh_my_tmux
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local"
}

# Test 4: Simple bash + Oh My Tmux (.tmux.conf.local) + atuin
test_bash_simple_tmux_oh_my_local_with_atuin() {
    setup_simple_bash
    setup_oh_my_tmux
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local"
}

# Test 5: Simple bash + Oh My Tmux (.config/tmux/tmux.conf.local) + no atuin
test_bash_simple_tmux_oh_my_config_no_atuin() {
    setup_simple_bash
    setup_oh_my_tmux_config_dir
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local"
}

# Test 6: Simple bash + Oh My Tmux (.config/tmux/tmux.conf.local) + atuin
test_bash_simple_tmux_oh_my_config_with_atuin() {
    setup_simple_bash
    setup_oh_my_tmux_config_dir
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local"
}

# Test 7: Oh My Bash + simple tmux + no atuin
test_bash_oh_my_tmux_simple_no_atuin() {
    setup_oh_my_bash
    setup_simple_tmux
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
}

# Test 8: Oh My Bash + simple tmux + atuin
test_bash_oh_my_tmux_simple_with_atuin() {
    setup_oh_my_bash
    setup_simple_tmux
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
}

# Test 9: Oh My Bash + Oh My Tmux (.tmux.conf.local) + no atuin
test_bash_oh_my_tmux_oh_my_local_no_atuin() {
    setup_oh_my_bash
    setup_oh_my_tmux
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
}

# Test 10: Oh My Bash + Oh My Tmux (.tmux.conf.local) + atuin
test_bash_oh_my_tmux_oh_my_local_with_atuin() {
    setup_oh_my_bash
    setup_oh_my_tmux
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
}

# Test 11: Oh My Bash + Oh My Tmux (.config/tmux/tmux.conf.local) + no atuin
test_bash_oh_my_tmux_oh_my_config_no_atuin() {
    setup_oh_my_bash
    setup_oh_my_tmux_config_dir
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
}

# Test 12: Oh My Bash + Oh My Tmux (.config/tmux/tmux.conf.local) + atuin
test_bash_oh_my_tmux_oh_my_config_with_atuin() {
    setup_oh_my_bash
    setup_oh_my_tmux_config_dir
    setup_atuin
    
    export SHELL="/bin/bash"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_bash_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.bashrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.bashrc" "Oh My Bash"
} 

# ZSH TESTS

# Test 13: Simple zsh + simple tmux + no atuin
test_zsh_simple_tmux_simple_no_atuin() {
    setup_simple_zsh
    setup_simple_tmux
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf"
}

# Test 14: Simple zsh + simple tmux + atuin
test_zsh_simple_tmux_simple_with_atuin() {
    setup_simple_zsh
    setup_simple_tmux
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf"
}

# Test 15: Simple zsh + Oh My Tmux (.tmux.conf.local) + no atuin
test_zsh_simple_tmux_oh_my_local_no_atuin() {
    setup_simple_zsh
    setup_oh_my_tmux
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local"
}

# Test 16: Simple zsh + Oh My Tmux (.tmux.conf.local) + atuin
test_zsh_simple_tmux_oh_my_local_with_atuin() {
    setup_simple_zsh
    setup_oh_my_tmux
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local"
}

# Test 17: Simple zsh + Oh My Tmux (.config/tmux/tmux.conf.local) + no atuin
test_zsh_simple_tmux_oh_my_config_no_atuin() {
    setup_simple_zsh
    setup_oh_my_tmux_config_dir
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local"
}

# Test 18: Simple zsh + Oh My Tmux (.config/tmux/tmux.conf.local) + atuin
test_zsh_simple_tmux_oh_my_config_with_atuin() {
    setup_simple_zsh
    setup_oh_my_tmux_config_dir
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local"
}

# Test 19: Oh My Zsh + simple tmux + no atuin
test_zsh_oh_my_tmux_simple_no_atuin() {
    setup_oh_my_zsh
    setup_simple_tmux
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
}

# Test 20: Oh My Zsh + simple tmux + atuin
test_zsh_oh_my_tmux_simple_with_atuin() {
    setup_oh_my_zsh
    setup_simple_tmux
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
}

# Test 21: Oh My Zsh + Oh My Tmux (.tmux.conf.local) + no atuin
test_zsh_oh_my_tmux_oh_my_local_no_atuin() {
    setup_oh_my_zsh
    setup_oh_my_tmux
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
}

# Test 22: Oh My Zsh + Oh My Tmux (.tmux.conf.local) + atuin
test_zsh_oh_my_tmux_oh_my_local_with_atuin() {
    setup_oh_my_zsh
    setup_oh_my_tmux
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
}

# Test 23: Oh My Zsh + Oh My Tmux (.config/tmux/tmux.conf.local) + no atuin
test_zsh_oh_my_tmux_oh_my_config_no_atuin() {
    setup_oh_my_zsh
    setup_oh_my_tmux_config_dir
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
}

# Test 24: Oh My Zsh + Oh My Tmux (.config/tmux/tmux.conf.local) + atuin
test_zsh_oh_my_tmux_oh_my_config_with_atuin() {
    setup_oh_my_zsh
    setup_oh_my_tmux_config_dir
    setup_atuin
    
    export SHELL="/bin/zsh"
    
    if ! run_installer "y\nn"; then
        echo -e "${RED}✗ Installer failed${NC}"
        return 1
    fi
    
    verify_shell_ai_scripts_installed && \
    verify_zsh_integration && \
    verify_tmux_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_no_duplicate_integration "$HOME/.zshrc" && \
    verify_no_duplicate_integration "$HOME/.config/tmux/tmux.conf.local" && \
    verify_existing_config_preserved "$HOME/.zshrc" "Oh My Zsh"
} 

# Test runner
main() {
    echo -e "${BLUE}Starting comprehensive installation tests...${NC}"
    echo -e "${YELLOW}This will test all combinations of shell configs, tmux configs, and atuin${NC}"
    
    # Check if we should run in debug mode for the first test
    if [[ "$1" == "debug" ]]; then
        echo -e "${YELLOW}Running first test in debug mode...${NC}"
        export SHELL_AI_TEST_DEBUG=1
    fi
    
    echo
    
    # Bash tests
    echo -e "${BLUE}=== BASH TESTS ===${NC}"
    
    # Run first test (might be in debug mode)
    run_test "Bash Simple + Tmux Simple + No Atuin" test_bash_simple_tmux_simple_no_atuin || true
    
    # Turn off debug mode after first test if it was enabled by debug parameter
    if [[ "$1" == "debug" ]]; then
        unset SHELL_AI_TEST_DEBUG
        echo -e "${YELLOW}Debug mode disabled for remaining tests${NC}"
    fi
    
    run_test "Bash Simple + Tmux Simple + Atuin" test_bash_simple_tmux_simple_with_atuin || true
    run_test "Bash Simple + Oh My Tmux Local + No Atuin" test_bash_simple_tmux_oh_my_local_no_atuin || true
    run_test "Bash Simple + Oh My Tmux Local + Atuin" test_bash_simple_tmux_oh_my_local_with_atuin || true
    run_test "Bash Simple + Oh My Tmux Config + No Atuin" test_bash_simple_tmux_oh_my_config_no_atuin || true
    run_test "Bash Simple + Oh My Tmux Config + Atuin" test_bash_simple_tmux_oh_my_config_with_atuin || true
    
    run_test "Oh My Bash + Tmux Simple + No Atuin" test_bash_oh_my_tmux_simple_no_atuin || true
    run_test "Oh My Bash + Tmux Simple + Atuin" test_bash_oh_my_tmux_simple_with_atuin || true
    run_test "Oh My Bash + Oh My Tmux Local + No Atuin" test_bash_oh_my_tmux_oh_my_local_no_atuin || true
    run_test "Oh My Bash + Oh My Tmux Local + Atuin" test_bash_oh_my_tmux_oh_my_local_with_atuin || true
    run_test "Oh My Bash + Oh My Tmux Config + No Atuin" test_bash_oh_my_tmux_oh_my_config_no_atuin || true
    run_test "Oh My Bash + Oh My Tmux Config + Atuin" test_bash_oh_my_tmux_oh_my_config_with_atuin || true
    
    echo -e "${BLUE}=== ZSH TESTS ===${NC}"
    
    run_test "Zsh Simple + Tmux Simple + No Atuin" test_zsh_simple_tmux_simple_no_atuin || true
    run_test "Zsh Simple + Tmux Simple + Atuin" test_zsh_simple_tmux_simple_with_atuin || true
    run_test "Zsh Simple + Oh My Tmux Local + No Atuin" test_zsh_simple_tmux_oh_my_local_no_atuin || true
    run_test "Zsh Simple + Oh My Tmux Local + Atuin" test_zsh_simple_tmux_oh_my_local_with_atuin || true
    run_test "Zsh Simple + Oh My Tmux Config + No Atuin" test_zsh_simple_tmux_oh_my_config_no_atuin || true
    run_test "Zsh Simple + Oh My Tmux Config + Atuin" test_zsh_simple_tmux_oh_my_config_with_atuin || true
    
    run_test "Oh My Zsh + Tmux Simple + No Atuin" test_zsh_oh_my_tmux_simple_no_atuin || true
    run_test "Oh My Zsh + Tmux Simple + Atuin" test_zsh_oh_my_tmux_simple_with_atuin || true
    run_test "Oh My Zsh + Oh My Tmux Local + No Atuin" test_zsh_oh_my_tmux_oh_my_local_no_atuin || true
    run_test "Oh My Zsh + Oh My Tmux Local + Atuin" test_zsh_oh_my_tmux_oh_my_local_with_atuin || true
    run_test "Oh My Zsh + Oh My Tmux Config + No Atuin" test_zsh_oh_my_tmux_oh_my_config_no_atuin || true
    run_test "Oh My Zsh + Oh My Tmux Config + Atuin" test_zsh_oh_my_tmux_oh_my_config_with_atuin || true
    
    # Print final summary
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 