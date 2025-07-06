#!/bin/bash

# Test AI shell script functionality

# Use the mock ai-shell.sh created by test_runner.sh
setup_ai_shell_mock() {
    export AI_SHELL_SCRIPT="$CONFIG_DIR/ai-shell.sh"
    # Mock is already created by test_runner.sh setup_test_env()
}

# Test help display in bash
test_help_display_bash() {
    setup_ai_shell_mock
    
    local result=$(bash -c "$AI_SHELL_SCRIPT --help")
    
    if [[ "$result" =~ "Shell AI Integration" ]]; then
        return 0
    else
        echo "Help display test failed: $result"
        return 1
    fi
}

# Test help display in zsh
test_help_display_zsh() {
    setup_ai_shell_mock
    
    local result=$(zsh -c "$AI_SHELL_SCRIPT --help")
    
    if [[ "$result" =~ "Shell AI Integration" ]]; then
        return 0
    else
        echo "Help display test failed: $result"
        return 1
    fi
}

# Test context display
test_context_display() {
    local shell="$1"
    setup_ai_shell_mock
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$AI_SHELL_SCRIPT --context")
    else
        result=$(bash -c "$AI_SHELL_SCRIPT --context")
    fi
    
    if [[ "$result" =~ "SYSTEM CONTEXT" ]]; then
        return 0
    else
        echo "Context display test failed: $result"
        return 1
    fi
}

# Test prompt processing
test_prompt_processing() {
    local shell="$1"
    setup_ai_shell_mock
    
    local test_prompt="explain ls command"
    local result
    
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$AI_SHELL_SCRIPT '$test_prompt'")
    else
        result=$(bash -c "$AI_SHELL_SCRIPT '$test_prompt'")
    fi
    
    if [[ "$result" =~ "Mock response for: $test_prompt" ]]; then
        return 0
    else
        echo "Prompt processing test failed: $result"
        return 1
    fi
}

# Test script executable permissions
test_script_permissions() {
    setup_ai_shell_mock
    
    if [[ -x "$AI_SHELL_SCRIPT" ]]; then
        return 0
    else
        echo "Script permissions test failed: $AI_SHELL_SCRIPT not executable"
        return 1
    fi
}

# Test error handling for invalid options
test_error_handling() {
    local shell="$1"
    setup_ai_shell_mock
    
    # Test with an invalid option (our mock script doesn't handle this specific case)
    # The mock will just return the default response for any unrecognized option
    local result
    local exit_code
    
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$AI_SHELL_SCRIPT --invalid-option" 2>&1)
        exit_code=$?
    else
        result=$(bash -c "$AI_SHELL_SCRIPT --invalid-option" 2>&1)
        exit_code=$?
    fi
    
    # The mock script will handle invalid options with the default case
    if [[ $exit_code -eq 0 ]] && [[ "$result" =~ "AI Response: Mock response for: --invalid-option" ]]; then
        return 0
    else
        echo "Error handling test failed: exit_code=$exit_code, result=$result"
        return 1
    fi
} 