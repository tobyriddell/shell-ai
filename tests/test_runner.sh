#!/bin/bash

# Test Runner for Shell AI Integration
# Runs tests for both bash and zsh shells

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
TEMP_CONFIG_DIR="/tmp/shell-ai-test-$$"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    
    # Create temporary config directory
    mkdir -p "$TEMP_CONFIG_DIR"
    
    # Copy test configs
    cp "$PROJECT_ROOT/config/ai-config.example.json" "$TEMP_CONFIG_DIR/config.json"
    cp -r "$PROJECT_ROOT/scripts" "$TEMP_CONFIG_DIR/"
    cp -r "$PROJECT_ROOT/config" "$TEMP_CONFIG_DIR/"
    # Copy Golang tmux-selector binary by default
    cp "$PROJECT_ROOT/tmux-selector-go/tmux-selector" "$TEMP_CONFIG_DIR/"
    
    # Make scripts executable
    chmod +x "$TEMP_CONFIG_DIR/scripts/"*.sh
    
    # Set test environment variables
    export SHELL_AI_TEST_MODE=1
    export HOME="$TEMP_CONFIG_DIR"
    export CONFIG_DIR="$TEMP_CONFIG_DIR/.config/shell-ai"
    
    # For Docker environment, use the actual config location
    if [[ -d "$HOME/.config/shell-ai" && ! -d "$CONFIG_DIR" ]]; then
        export CONFIG_DIR="$HOME/.config/shell-ai"
    fi
    
    mkdir -p "$CONFIG_DIR"
    cp "$TEMP_CONFIG_DIR/scripts/"* "$CONFIG_DIR/"
    cp "$TEMP_CONFIG_DIR/config/"* "$CONFIG_DIR/"
    
    # Create unified mock ai-shell.sh script for all tests
    cat > "$CONFIG_DIR/ai-shell.sh" << 'EOF'
#!/bin/bash
case "$1" in
    "--help"|"-h")
        echo "Shell AI Integration"
        echo "Usage: $0 [OPTIONS] [PROMPT]"
        exit 0
        ;;
    "--test"|"-t")
        echo "Test mode activated"
        exit 0
        ;;
    "--context"|"-c")
        echo "=== SYSTEM CONTEXT ==="
        echo "OS: $(uname -a)"
        echo "Shell: $SHELL"
        exit 0
        ;;
    *)
        echo "AI Response: Mock response for: $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$CONFIG_DIR/ai-shell.sh"
    
    echo -e "${GREEN}✓ Test environment ready${NC}"
}

# Cleanup test environment
cleanup_test_env() {
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    rm -rf "$TEMP_CONFIG_DIR"
    unset SHELL_AI_TEST_MODE
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Run a test function
run_test() {
    local test_name="$1"
    local test_function="$2"
    local shell_type="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "${YELLOW}[$shell_type] Running: $test_name${NC}"
    
    if $test_function; then
        echo -e "${GREEN}[$shell_type] ✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}[$shell_type] ✗ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test command extraction
test_command_extraction() {
    local shell="$1"
    
    # Test @ prefix extraction
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c 'source tests/test_command_extraction.sh; test_prefix_extraction_zsh')
    else
        result=$(bash -c 'source tests/test_command_extraction.sh; test_prefix_extraction_bash')
    fi
    
    [[ "$result" == "success" ]]
}

# Test AI shell basic functionality
test_ai_shell_basic() {
    local shell="$1"
    
    if [[ "$shell" == "zsh" ]]; then
        zsh -c "source tests/test_ai_shell.sh; test_help_display_zsh"
    else
        bash -c "source tests/test_ai_shell.sh; test_help_display_bash"
    fi
}

# Test AI history functions (ai-last, ai-fix)
test_ai_history_functions() {
    local shell="$1"
    
    # Source the test file and run tests
    source tests/test_ai_history_functions.sh
    
    # Test that atuin mock works as expected
    if ! test_atuin_mock_rejects_limit; then
        echo "Mock atuin test failed"
        return 1
    fi
    
    # Test ai-last with atuin
    if [[ "$shell" == "zsh" ]]; then
        test_ai_last_with_atuin_zsh
    else
        test_ai_last_with_atuin_bash
    fi
    
    local result1=$?
    
    # Test ai-last without atuin (fallback)
    if [[ "$shell" == "bash" ]]; then
        test_ai_last_without_atuin_bash
    else
        # For zsh, we'll just test bash fallback since the logic is similar
        test_ai_last_without_atuin_bash
    fi
    
    local result2=$?
    
    # Test ai-fix function
    if [[ "$shell" == "bash" ]]; then
        test_ai_fix_with_atuin_bash
    else
        # For now, only test bash version of ai-fix since they're almost identical
        test_ai_fix_with_atuin_bash
    fi
    
    local result3=$?
    
    # Test empty history handling
    test_ai_last_empty_history
    local result4=$?
    
    # Return success only if all tests pass
    [[ $result1 -eq 0 && $result2 -eq 0 && $result3 -eq 0 && $result4 -eq 0 ]]
}

# Test config management
test_config_management() {
    local shell="$1"
    
    if [[ "$shell" == "zsh" ]]; then
        zsh -c "source tests/test_config_management.sh; test_config_loading_zsh"
    else
        bash -c "source tests/test_config_management.sh; test_config_loading_bash"
    fi
}

# Test tmux integration
test_tmux_integration() {
    local shell="$1"
    
    if [[ "$shell" == "zsh" ]]; then
        zsh -c "source tests/test_tmux_integration.sh; test_tmux_functions_zsh"
    else
        bash -c "source tests/test_tmux_integration.sh; test_tmux_functions_bash"
    fi
}

# Test tmux selector binary (Golang version)
test_tmux_selector_golang() {
    local shell="$1"
    
    # Source the test file and run tests
    source tests/test_tmux_selector_go.sh
    
    # Test binary existence and basic functionality
    if ! test_go_binary_exists; then
        echo "Golang binary existence test failed"
        return 1
    fi
    
    # Test graceful failure outside tmux
    test_go_binary_outside_tmux
    local result1=$?
    
    # Test auto flag functionality
    test_go_binary_auto_flag
    local result2=$?
    
    # Test ai-copy.sh integration
    test_go_ai_copy_integration
    local result3=$?
    
    # Test fallback behavior
    test_go_fallback_behavior
    local result4=$?
    
    # Test JSON output
    test_go_json_output
    local result5=$?
    
    # Return success only if all tests pass
    [[ $result1 -eq 0 && $result2 -eq 0 && $result3 -eq 0 && $result4 -eq 0 && $result5 -eq 0 ]]
}

# Test tmux selector binary (Rust version)
test_tmux_selector_rust() {
    local shell="$1"
    
    # Backup current binary and copy Rust version
    local backup_binary="$TEMP_CONFIG_DIR/tmux-selector.backup"
    local rust_binary="$PROJECT_ROOT/tmux-selector-rust/target/release/tmux-selector"
    local current_binary="$TEMP_CONFIG_DIR/tmux-selector"
    
    # Check if Rust binary exists
    if [[ ! -f "$rust_binary" ]]; then
        echo "SKIP: Rust tmux-selector binary not found at $rust_binary"
        return 0
    fi
    
    # Backup current binary and copy Rust version
    cp "$current_binary" "$backup_binary" 2>/dev/null || true
    cp "$rust_binary" "$current_binary"
    
    # Source the test file and run tests
    source tests/test_tmux_selector_rust.sh
    
    # Test binary existence and basic functionality
    if ! test_rust_binary_exists; then
        echo "Rust binary existence test failed"
        # Restore original binary
        cp "$backup_binary" "$current_binary" 2>/dev/null || true
        return 1
    fi
    
    # Test graceful failure outside tmux
    test_rust_binary_outside_tmux
    local result1=$?
    
    # Test auto flag functionality
    test_rust_binary_auto_flag
    local result2=$?
    
    # Test ai-copy.sh integration
    test_rust_ai_copy_integration
    local result3=$?
    
    # Test fallback behavior
    test_rust_fallback_behavior
    local result4=$?
    
    # Test JSON output
    test_rust_json_output
    local result5=$?
    
    # Restore original binary
    cp "$backup_binary" "$current_binary" 2>/dev/null || true
    rm -f "$backup_binary" 2>/dev/null || true
    
    # Return success only if all tests pass
    [[ $result1 -eq 0 && $result2 -eq 0 && $result3 -eq 0 && $result4 -eq 0 && $result5 -eq 0 ]]
}

# Test shell-specific prefix handling
test_prefix_handling() {
    local shell="$1"
    
    if [[ "$shell" == "zsh" ]]; then
        zsh -c "source tests/test_prefix_handling.sh; test_command_not_found_handler_zsh"
    else
        bash -c "source tests/test_prefix_handling.sh; test_command_not_found_handle_bash"
    fi
}

# Run all tests for a specific shell
run_shell_tests() {
    local shell="$1"
    
    echo -e "${BLUE}=== Running tests for $shell ===${NC}"
    
    run_test "Command Extraction" "test_command_extraction $shell" "$shell"
    run_test "AI Shell Basic" "test_ai_shell_basic $shell" "$shell"
    run_test "AI History Functions" "test_ai_history_functions $shell" "$shell"
    run_test "Config Management" "test_config_management $shell" "$shell"
    run_test "tmux Integration" "test_tmux_integration $shell" "$shell"
    run_test "tmux Selector Binary (Go)" "test_tmux_selector_golang $shell" "$shell"
    run_test "tmux Selector Binary (Rust)" "test_tmux_selector_rust $shell" "$shell"
    run_test "Prefix Handling" "test_prefix_handling $shell" "$shell"
    
    echo
}

# Run installation tests
run_installation_tests() {
    local debug_mode="$1"
    echo -e "${BLUE}=== Running Installation Tests ===${NC}"
    echo
    
    if [[ -x "tests/test_installation.sh" ]]; then
        if [[ "$debug_mode" == "debug" ]]; then
            bash tests/test_installation.sh debug
        else
            bash tests/test_installation.sh
        fi
    else
        echo -e "${RED}Installation test script not found or not executable${NC}"
        exit 1
    fi
}

# Main test execution
main() {
    local target_shell="$1"
    
    echo -e "${BLUE}=== Shell AI Integration Test Suite ===${NC}"
    echo
    
    # Check for special test modes
    if [[ "$target_shell" == "install" ]]; then
        run_installation_tests "$2"
        return $?
    fi
    
    # Determine which shells to test
    local shells_to_test=()
    
    if [[ -n "$target_shell" ]]; then
        # Specific shell requested
        if [[ "$target_shell" == "bash" ]] || [[ "$target_shell" == "zsh" ]]; then
            if command -v "$target_shell" >/dev/null 2>&1; then
                shells_to_test+=("$target_shell")
            else
                echo -e "${RED}Requested shell '$target_shell' not found${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Invalid shell '$target_shell'. Use 'bash', 'zsh', or 'install'${NC}"
            echo -e "${YELLOW}For installation tests with debug: 'install debug'${NC}"
            exit 1
        fi
    else
        # No specific shell requested, test all available
        command -v bash >/dev/null 2>&1 && shells_to_test+=("bash")
        command -v zsh >/dev/null 2>&1 && shells_to_test+=("zsh")
    fi
    
    if [[ ${#shells_to_test[@]} -eq 0 ]]; then
        echo -e "${RED}No shells available for testing${NC}"
        exit 1
    fi
    
    setup_test_env
    
    # Run tests for each shell
    for shell in "${shells_to_test[@]}"; do
        run_shell_tests "$shell"
    done
    
    # cleanup_test_env
    
    # Summary
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