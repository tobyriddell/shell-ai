#!/bin/bash

# Test shell-specific prefix handling

# Test bash command_not_found_handle function
test_command_not_found_handle_bash() {
    # Create bash test script that sources the real integration
    local bash_test_script="$CONFIG_DIR/test_bash_handler.sh"
    cat > "$bash_test_script" << EOF
#!/bin/bash
# Source the real bash integration
source "$CONFIG_DIR/bashrc-ai.sh"

# Test @ prefix command (only capture the handler's output, not the AI script's)
command_not_found_handle "@test prompt" 2>/dev/null | head -n1
EOF
    
    local result=$(bash "$bash_test_script")
    if [[ "$result" == "🤖 AI Query: test prompt" ]]; then
        return 0
    else
        echo "bash command_not_found_handle test failed: $result"
        return 1
    fi
}

# Test zsh command_not_found_handler function
test_command_not_found_handler_zsh() {
    # Create zsh test script that sources the real integration
    local zsh_test_script="$CONFIG_DIR/test_zsh_handler.zsh"
    cat > "$zsh_test_script" << EOF
#!/bin/zsh
# Source the real zsh integration
source "$CONFIG_DIR/zshrc-ai.sh"

# Test the function (only capture the handler's output, not the AI script's)
command_not_found_handler "@zsh test prompt" 2>/dev/null | head -n1
EOF
    
    local result=$(zsh "$zsh_test_script")

    if [[ "$result" == "🤖 AI Query: zsh test prompt" ]]; then
        return 0
    else
        echo "zsh command_not_found_handler test failed: $result"
        return 1
    fi
}

# Test prefix extraction with multiple words
test_multi_word_prefix() {
    local shell="$1"
    
    local test_handler_script="$CONFIG_DIR/test_multiword_${shell}.sh"
    
    if [[ "$shell" == "zsh" ]]; then
        cat > "$test_handler_script" << 'EOF'
#!/bin/zsh
cmd="@how do I list all files recursively"
ai_prompt="${cmd#@}"
echo "$ai_prompt"
EOF
    else
        cat > "$test_handler_script" << 'EOF'
#!/bin/bash
cmd="@how do I list all files recursively"
ai_prompt="${cmd#@}"
echo "$ai_prompt"
EOF
    fi
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh "$test_handler_script")
    else
        result=$(bash "$test_handler_script")
    fi
    
    if [[ "$result" == "how do I list all files recursively" ]]; then
        return 0
    else
        echo "multi-word prefix test failed: $result"
        return 1
    fi
}

# Test empty prefix handling
test_empty_prefix() {
    local shell="$1"
    
    local test_handler_script="$CONFIG_DIR/test_empty_${shell}.sh"
    
    if [[ "$shell" == "zsh" ]]; then
        cat > "$test_handler_script" << 'EOF'
#!/bin/zsh
cmd="@"
ai_prompt="${cmd#@}"
if [[ -z "$ai_prompt" ]]; then
    echo "EMPTY"
else
    echo "NOT_EMPTY:$ai_prompt"
fi
EOF
    else
        cat > "$test_handler_script" << 'EOF'
#!/bin/bash
cmd="@"
ai_prompt="${cmd#@}"
if [[ -z "$ai_prompt" ]]; then
    echo "EMPTY"
else
    echo "NOT_EMPTY:$ai_prompt"
fi
EOF
    fi
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh "$test_handler_script")
    else
        result=$(bash "$test_handler_script")
    fi
    
    if [[ "$result" == "EMPTY" ]]; then
        return 0
    else
        echo "empty prefix test failed: $result"
        return 1
    fi
}

# Test special characters in prefix
test_special_chars_prefix() {
    local shell="$1"
    
    local test_handler_script="$CONFIG_DIR/test_special_${shell}.sh"
    
    if [[ "$shell" == "zsh" ]]; then
        cat > "$test_handler_script" << 'EOF'
#!/bin/zsh
cmd="@find files with \"quotes\" and spaces"
ai_prompt="${cmd#@}"
echo "$ai_prompt"
EOF
    else
        cat > "$test_handler_script" << 'EOF'
#!/bin/bash
cmd="@find files with \"quotes\" and spaces"
ai_prompt="${cmd#@}"
echo "$ai_prompt"
EOF
    fi
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh "$test_handler_script")
    else
        result=$(bash "$test_handler_script")
    fi
    
    if [[ "$result" == 'find files with "quotes" and spaces' ]]; then
        return 0
    else
        echo "special chars prefix test failed: $result"
        return 1
    fi
}

# Test non-prefix command handling
test_non_prefix_command() {
    local shell="$1"
    
    # Test non-prefix command handling using real integration
    local test_handler_script="$CONFIG_DIR/test_nonprefix_${shell}.sh"
    
    if [[ "$shell" == "zsh" ]]; then
        cat > "$test_handler_script" << EOF
#!/bin/zsh
# Source the real zsh integration
source "$CONFIG_DIR/zshrc-ai.sh"

# Test non-prefix command (should fall back to default behavior)
command_not_found_handler "nonexistent_command"
EOF
    else
        cat > "$test_handler_script" << EOF
#!/bin/bash
# Source the real bash integration
source "$CONFIG_DIR/bashrc-ai.sh"

# Test non-prefix command (should fall back to default behavior)
command_not_found_handle "nonexistent_command"
EOF
    fi
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh "$test_handler_script")
    else
        result=$(bash "$test_handler_script")
    fi
    
    # The real implementation should output the default "command not found" message
    if [[ "$result" == *"command not found"* ]]; then
        return 0
    else
        echo "non-prefix command test failed: $result"
        return 1
    fi
} 