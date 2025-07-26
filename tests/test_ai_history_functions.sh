#!/bin/bash

# Test AI history functions (ai-last, ai-fix)
# These functions should work with both atuin and standard history

# Mock atuin command that mimics real atuin behavior
setup_atuin_mock() {
    local temp_atuin_dir="/tmp/shell-ai-test-atuin-$$"
    mkdir -p "$temp_atuin_dir"
    
    # Create a mock atuin script
    cat > "$temp_atuin_dir/atuin" << 'EOF'
#!/bin/bash
if [[ "$1" == "history" && "$2" == "list" ]]; then
    # Check for unsupported --limit flag
    if [[ "$*" =~ --limit ]]; then
        echo "error: unexpected argument '--limit' found" >&2
        echo "" >&2
        echo "Usage: atuin history list [OPTIONS]" >&2
        echo "" >&2
        echo "For more information, try '--help'." >&2
        exit 1
    fi
    # Return mock history (most recent first)
    echo "ls -la"
    echo "cd /home/user"
    echo "git status"
elif [[ "$1" == "init" ]]; then
    # Mock atuin init - just return empty so it doesn't interfere
    echo ""
else
    echo "Mock atuin: command not supported"
    exit 1
fi
EOF
    chmod +x "$temp_atuin_dir/atuin"
    export PATH="$temp_atuin_dir:$PATH"
    export MOCK_ATUIN_DIR="$temp_atuin_dir"
}

# Remove atuin mock
cleanup_atuin_mock() {
    if [[ -n "$MOCK_ATUIN_DIR" && -d "$MOCK_ATUIN_DIR" ]]; then
        rm -rf "$MOCK_ATUIN_DIR"
        export PATH="${PATH#$MOCK_ATUIN_DIR:}"
        unset MOCK_ATUIN_DIR
    fi
}

# Test ai-last function with atuin (bash)
test_ai_last_with_atuin_bash() {
    setup_atuin_mock
    
    # Set up the home directory to avoid path duplication
    local test_home="/tmp/shell-ai-test-ai-last-$$"
    mkdir -p "$test_home/.config/shell-ai"
    export HOME="$test_home"
    
    # Copy the config files to the test location
    cp "$CONFIG_DIR/bashrc-ai.sh" "$test_home/.config/shell-ai/"
    
    # Create a mock ai-shell.sh that just echoes the command it would run
    local mock_ai_shell="$test_home/.config/shell-ai/ai-shell.sh"
    cat > "$mock_ai_shell" << 'EOF'
#!/bin/bash
echo "AI called with: $*"
EOF
    chmod +x "$mock_ai_shell"
    
    # Test ai-last function
    local result
    result=$(bash -c "
        source '$test_home/.config/shell-ai/bashrc-ai.sh'
        ai-last 2>&1
    ")
    
    cleanup_atuin_mock
    rm -rf "$test_home"
    
    # Check that it doesn't contain the --limit error
    if [[ "$result" =~ "unexpected argument '--limit'" ]]; then
        echo "FAIL: ai-last still using unsupported --limit flag"
        return 1
    fi
    
    # Check that AI was called with expected command
    if [[ "$result" =~ "AI called with: Explain this command: ls -la" ]]; then
        return 0
    else
        echo "FAIL: Expected AI call not found. Got: $result"
        return 1
    fi
}

# Test ai-last function with atuin (zsh)
test_ai_last_with_atuin_zsh() {
    setup_atuin_mock
    
    # Set up the home directory to avoid path duplication
    local test_home="/tmp/shell-ai-test-ai-last-zsh-$$"
    mkdir -p "$test_home/.config/shell-ai"
    export HOME="$test_home"
    
    # Copy the config files to the test location
    cp "$CONFIG_DIR/zshrc-ai.sh" "$test_home/.config/shell-ai/"
    
    # Create a mock ai-shell.sh that just echoes the command it would run
    local mock_ai_shell="$test_home/.config/shell-ai/ai-shell.sh"
    cat > "$mock_ai_shell" << 'EOF'
#!/bin/bash
echo "AI called with: $*"
EOF
    chmod +x "$mock_ai_shell"
    
    # Test ai-last function
    local result
    result=$(zsh -c "
        source '$test_home/.config/shell-ai/zshrc-ai.sh'
        ai-last 2>&1
    ")
    
    cleanup_atuin_mock
    rm -rf "$test_home"
    
    # Check that it doesn't contain the --limit error
    if [[ "$result" =~ "unexpected argument '--limit'" ]]; then
        echo "FAIL: ai-last still using unsupported --limit flag"
        return 1
    fi
    
    # Check that AI was called with expected command
    if [[ "$result" =~ "AI called with: Explain this command: ls -la" ]]; then
        return 0
    else
        echo "FAIL: Expected AI call not found. Got: $result"
        return 1
    fi
}

# Test ai-last function without atuin (bash fallback)
test_ai_last_without_atuin_bash() {
    # Remove atuin from PATH to test fallback
    local old_path="$PATH"
    export PATH=$(echo "$PATH" | sed 's/[^:]*atuin[^:]*://g')
    
    # Set up the home directory to avoid path duplication
    local test_home="/tmp/shell-ai-test-ai-last-noatuin-$$"
    mkdir -p "$test_home/.config/shell-ai"
    export HOME="$test_home"
    
    # Copy the config files to the test location
    cp "$CONFIG_DIR/bashrc-ai.sh" "$test_home/.config/shell-ai/"
    
    # Create a mock ai-shell.sh
    local mock_ai_shell="$test_home/.config/shell-ai/ai-shell.sh"
    cat > "$mock_ai_shell" << 'EOF'
#!/bin/bash
echo "AI called with: $*"
EOF
    chmod +x "$mock_ai_shell"
    
    # Test ai-last function
    local result
    result=$(bash -c "
        # Mock history command
        history() { echo '  123  test command'; }
        export -f history
        source '$test_home/.config/shell-ai/bashrc-ai.sh'
        ai-last 2>&1
    ")
    
    export PATH="$old_path"
    rm -rf "$test_home"
    
    # Check that AI was called with the fallback history
    if [[ "$result" =~ "AI called with: Explain this command: test command" ]]; then
        return 0
    else
        echo "FAIL: Fallback history not working. Got: $result"
        return 1
    fi
}

# Test ai-fix function with atuin (bash)
test_ai_fix_with_atuin_bash() {
    setup_atuin_mock
    
    # Set up the home directory to avoid path duplication
    local test_home="/tmp/shell-ai-test-ai-fix-$$"
    mkdir -p "$test_home/.config/shell-ai"
    export HOME="$test_home"
    
    # Copy the config files to the test location
    cp "$CONFIG_DIR/bashrc-ai.sh" "$test_home/.config/shell-ai/"
    
    # Create a mock ai-shell.sh
    local mock_ai_shell="$test_home/.config/shell-ai/ai-shell.sh"
    cat > "$mock_ai_shell" << 'EOF'
#!/bin/bash
echo "AI called with: $*"
EOF
    chmod +x "$mock_ai_shell"
    
    # Test ai-fix function
    local result
    result=$(bash -c "
        source '$test_home/.config/shell-ai/bashrc-ai.sh'
        ai-fix 2>&1
    ")
    
    cleanup_atuin_mock
    rm -rf "$test_home"
    
    # Check that it doesn't contain the --limit error
    if [[ "$result" =~ "unexpected argument '--limit'" ]]; then
        echo "FAIL: ai-fix still using unsupported --limit flag"
        return 1
    fi
    
    # Check that AI was called with expected fix request
    if [[ "$result" =~ "AI called with: The command 'ls -la' failed. Please suggest how to fix it or provide the correct command." ]]; then
        return 0
    else
        echo "FAIL: Expected AI fix call not found. Got: $result"
        return 1
    fi
}

# Test that atuin mock actually fails with --limit (verification test)
test_atuin_mock_rejects_limit() {
    setup_atuin_mock
    
    # Test that our mock correctly rejects --limit
    local result
    result=$(atuin history list --limit 1 2>&1 || true)
    
    cleanup_atuin_mock
    
    if [[ "$result" =~ "unexpected argument '--limit'" ]]; then
        return 0
    else
        echo "FAIL: Mock atuin should reject --limit flag. Got: $result"
        return 1
    fi
}

# Test empty history handling
test_ai_last_empty_history() {
    # Set up the home directory to avoid path duplication
    local test_home="/tmp/shell-ai-test-ai-last-empty-$$"
    mkdir -p "$test_home/.config/shell-ai"
    export HOME="$test_home"
    
    # Copy the config files to the test location
    cp "$CONFIG_DIR/bashrc-ai.sh" "$test_home/.config/shell-ai/"
    
    # Create a mock ai-shell.sh
    local mock_ai_shell="$test_home/.config/shell-ai/ai-shell.sh"
    cat > "$mock_ai_shell" << 'EOF'
#!/bin/bash
echo "AI called with: $*"
EOF
    chmod +x "$mock_ai_shell"
    
    # Test with empty history
    local result
    result=$(bash -c "
        # Mock empty history
        history() { echo ''; }
        export -f history
        # Remove atuin from PATH
        export PATH=\$(echo \"\$PATH\" | sed 's/[^:]*atuin[^:]*://g')
        source '$test_home/.config/shell-ai/bashrc-ai.sh'
        ai-last 2>&1
    ")
    
    rm -rf "$test_home"
    
    # Should show "No recent command found"
    if [[ "$result" =~ "No recent command found" ]]; then
        return 0
    else
        echo "FAIL: Should handle empty history gracefully. Got: $result"
        return 1
    fi
} 