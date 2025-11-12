#!/bin/bash

# Docker Go Implementation Test Suite
# Tests the Go shell-ai implementation in Docker containers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Utility function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    
    if $test_function; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test that shell-ai binary exists and is executable
test_shell_ai_binary_exists() {
    if command -v shell-ai >/dev/null 2>&1; then
        echo "shell-ai binary found in PATH"
        return 0
    else
        echo "shell-ai binary not found in PATH"
        return 1
    fi
}

# Test shell-ai help command
test_shell_ai_help() {
    local output
    output=$(shell-ai --help 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && "$output" == *"Shell AI Integration"* ]]; then
        echo "Help command works correctly"
        return 0
    else
        echo "Help command failed or unexpected output"
        echo "Exit code: $exit_code"
        echo "Output: $output"
        return 1
    fi
}

# Test shell-ai version/build info
test_shell_ai_version() {
    local output
    output=$(shell-ai --version 2>&1 || true)
    
    # Test that the binary handles unknown flags gracefully
    if [[ "$output" == *"unknown flag"* ]] && [[ "$output" == *"--version"* ]]; then
        echo "Correctly handles unknown --version flag"
        return 0
    else
        echo "Unexpected response to --version flag: $output"
        return 1
    fi
}

# Test shell-ai without configuration (should fail gracefully)
test_shell_ai_no_config() {
    local output
    output=$(shell-ai ask "test" 2>&1 || true)
    
    if [[ "$output" == *"no enabled providers"* ]] || [[ "$output" == *"configuration"* ]]; then
        echo "Correctly fails when no providers configured"
        return 0
    else
        echo "Unexpected error message: $output"
        return 1
    fi
}

# Test shell-ai with --no-history flag
test_shell_ai_no_history_flag() {
    local output
    output=$(shell-ai ask --no-history --no-panes "test" 2>&1 || true)
    
    if [[ "$output" == *"no enabled providers"* ]] || [[ "$output" == *"configuration"* ]]; then
        echo "Correctly processes flags and fails appropriately"
        return 0
    else
        echo "Unexpected response: $output"
        return 1
    fi
}

# Test shell-ai setup command (dry run)
test_shell_ai_setup() {
    local output
    output=$(timeout 5 shell-ai setup 2>&1 || true)
    
    # Setup should start and either prompt or show configuration
    if [[ "$output" == *"provider"* ]] || [[ "$output" == *"config"* ]] || [[ "$output" == *"setup"* ]]; then
        echo "Setup command responds appropriately"
        return 0
    else
        echo "Setup command unexpected output: $output"
        return 1
    fi
}

# Test that tmux is available
test_tmux_available() {
    if command -v tmux >/dev/null 2>&1; then
        echo "tmux is available"
        local version
        version=$(tmux -V)
        echo "tmux version: $version"
        return 0
    else
        echo "tmux not found"
        return 1
    fi
}

# Test that atuin is available (optional)
test_atuin_available() {
    if command -v atuin >/dev/null 2>&1; then
        echo "atuin is available"
        local version
        version=$(atuin --version 2>&1 || echo "unknown")
        echo "atuin version: $version"
        return 0
    else
        echo "atuin not found (optional dependency)"
        return 0  # Not required, so still pass
    fi
}

# Test that Go is available
test_go_available() {
    if command -v go >/dev/null 2>&1; then
        echo "Go is available"
        local version
        version=$(go version)
        echo "Go version: $version"
        return 0
    else
        echo "Go not found"
        return 1
    fi
}

# Test shell aliases are set up
test_shell_aliases() {
    # Check for the appropriate shell configuration file
    # Use the current shell to determine which config file to check
    local shell_config=""
    local current_shell=$(basename "$SHELL" 2>/dev/null || echo "bash")
    
    if [[ "$current_shell" == "zsh" ]] && [[ -f "$HOME/.zshrc" ]]; then
        shell_config="$HOME/.zshrc"
        echo "Checking .zshrc for aliases (zsh shell detected)"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_config="$HOME/.bashrc"
        echo "Checking .bashrc for aliases"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_config="$HOME/.zshrc"
        echo "Checking .zshrc for aliases (fallback)"
    else
        echo "No shell configuration file found (.bashrc or .zshrc)"
        return 1
    fi
    
    if grep -q "alias ai=" "$shell_config"; then
        echo "ai alias definition found in $shell_config"
        # Check if the alias is properly defined (look for the Go implementation alias)
        if grep -q 'alias ai="shell-ai ask"' "$shell_config"; then
            echo "Go implementation alias found in $shell_config"
            return 0
        else
            echo "Go implementation alias not found in $shell_config"
            return 1
        fi
    else
        echo "ai alias definition not found in $shell_config"
        return 1
    fi
}

# Test tmux selector functionality is integrated into shell-ai
test_tmux_selector_binary() {
    # The tmux-selector functionality is now integrated into the main shell-ai binary
    # Test that shell-ai has the integrated tmux functionality
    local output
    output=$(shell-ai --help 2>&1 || true)
    
    if [[ "$output" == *"tmux"* ]] || [[ "$output" == *"interactive"* ]]; then
        echo "tmux-selector functionality is integrated into shell-ai binary"
        return 0
    else
        echo "tmux-selector functionality not found in shell-ai binary"
        return 1
    fi
}

# Test shell-ai configuration directory structure
test_config_directory_structure() {
    local config_dir="$HOME/.config/shell-ai"
    
    if [[ ! -d "$config_dir" ]]; then
        echo "Config directory does not exist: $config_dir"
        return 1
    fi
    
    echo "Config directory exists: $config_dir"
    echo "Contents:"
    ls -la "$config_dir" || true
    
    return 0
}

# Test that legacy bash scripts exist (for fallback)
test_legacy_scripts_exist() {
    local config_dir="$HOME/.config/shell-ai"
    local required_scripts=("ai-shell.sh" "ai-copy.sh")
    
    for script in "${required_scripts[@]}"; do
        local script_path="$config_dir/$script"
        if [[ -f "$script_path" ]]; then
            echo "Legacy script found: $script"
        else
            echo "Legacy script missing: $script"
            return 1
        fi
    done
    
    return 0
}

# Test shell-ai binary is accessible via PATH
test_path_includes_local_bin() {
    # In Docker, PATH may not include ~/.local/bin unless we source bashrc
    # Let's check if the directory exists and if shell-ai is accessible
    if [[ -d "$HOME/.local/bin" ]]; then
        echo "~/.local/bin directory exists"
        if command -v shell-ai >/dev/null 2>&1; then
            echo "shell-ai is accessible via PATH (either /usr/local/bin or ~/.local/bin)"
            return 0
        else
            echo "shell-ai not accessible despite directory existing"
            return 1
        fi
    else
        # If ~/.local/bin doesn't exist but shell-ai works, that's still OK
        if command -v shell-ai >/dev/null 2>&1; then
            echo "shell-ai accessible via system PATH (/usr/local/bin)"
            return 0
        else
            echo "Neither ~/.local/bin exists nor shell-ai accessible"
            return 1
        fi
    fi
}

# Test shell-ai can read build metadata
test_shell_ai_build_info() {
    # Create a simple test to verify the binary was built correctly
    local output
    output=$(shell-ai ask --help 2>&1 || true)
    
    if [[ "$output" == *"ask"* ]] && [[ "$output" == *"prompt"* ]]; then
        echo "Binary shows correct command structure"
        return 0
    else
        echo "Binary may not be built correctly"
        echo "Output: $output"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}=== Shell AI Go Implementation Docker Test Suite ===${NC}"
    echo
    
    # System dependency tests
    run_test "Go Available" test_go_available
    run_test "tmux Available" test_tmux_available
    run_test "Atuin Available (optional)" test_atuin_available
    
    # Binary and installation tests
    run_test "shell-ai Binary Exists" test_shell_ai_binary_exists
    run_test "shell-ai Help Command" test_shell_ai_help
    run_test "shell-ai Unknown Flag Handling" test_shell_ai_version
    run_test "shell-ai Build Info" test_shell_ai_build_info
    
    # Configuration and structure tests
    run_test "Configuration Directory Structure" test_config_directory_structure
    run_test "shell-ai Binary Accessible" test_path_includes_local_bin
    run_test "tmux Selector Binary" test_tmux_selector_binary
    run_test "Legacy Scripts Exist" test_legacy_scripts_exist
    
    # Functional tests
    run_test "shell-ai No Config (graceful failure)" test_shell_ai_no_config
    run_test "shell-ai Flag Processing" test_shell_ai_no_history_flag
    run_test "shell-ai Setup Command" test_shell_ai_setup
    run_test "Shell Aliases" test_shell_aliases
    
    echo
    echo -e "${BLUE}=== Test Results ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Check if being sourced or run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

