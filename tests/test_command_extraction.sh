#!/bin/bash

# Test command extraction and prefix handling

# Test prefix extraction in bash
test_prefix_extraction_bash() {
    # Simulate bash prefix handling
    local cmd="@how do I list files"
    local prefix="${cmd#@}"
    
    if [[ "$prefix" == "how do I list files" ]]; then
        echo "success"
        return 0
    else
        echo "failed: expected 'how do I list files', got '$prefix'"
        return 1
    fi
}

# Test prefix extraction in zsh
test_prefix_extraction_zsh() {
    # Simulate zsh prefix handling
    local cmd="@explain this command"
    local prefix="${cmd#@}"
    
    if [[ "$prefix" == "explain this command" ]]; then
        echo "success"
        return 0
    else
        echo "failed: expected 'explain this command', got '$prefix'"
        return 1
    fi
}

# Test AI function prefix handling
test_ai_function_calls() {
    local shell="$1"
    
    # Mock the ai_prefix_handler function
    ai_prefix_handler() {
        local cmd="$1"
        shift
        local prompt="$*"
        
        case "$cmd" in
            "ai"|"AI")
                echo "ai_called_with: $prompt"
                return 0
                ;;
            *)
                echo "unknown_command: $cmd"
                return 1
                ;;
        esac
    }
    
    # Test valid AI command
    local result=$(ai_prefix_handler "ai" "test prompt")
    if [[ "$result" == "ai_called_with: test prompt" ]]; then
        return 0
    else
        echo "AI function test failed: $result"
        return 1
    fi
}

# Test command argument parsing
test_command_parsing() {
    local shell="$1"
    
    # Test multi-word command parsing
    local cmd="@how do I find files with spaces in names"
    local args=("$cmd")
    
    # Remove @ prefix
    local first_arg="${args[0]}"
    local prompt="${first_arg#@}"
    
    if [[ "$prompt" == "how do I find files with spaces in names" ]]; then
        return 0
    else
        echo "Command parsing failed: expected 'how do I find files with spaces in names', got '$prompt'"
        return 1
    fi
}

# Test special characters in prompts
test_special_characters() {
    local shell="$1"
    
    # Test prompt with special characters
    local cmd="@find files with \"quotes\" and 'apostrophes'"
    local prompt="${cmd#@}"
    
    if [[ "$prompt" == "find files with \"quotes\" and 'apostrophes'" ]]; then
        return 0
    else
        echo "Special character test failed: $prompt"
        return 1
    fi
}

# Test empty prompt handling
test_empty_prompt() {
    local shell="$1"
    
    local cmd="@"
    local prompt="${cmd#@}"
    
    if [[ -z "$prompt" ]]; then
        return 0
    else
        echo "Empty prompt test failed: expected empty, got '$prompt'"
        return 1
    fi
} 