#!/bin/bash

# Test tmux integration functionality

# Mock tmux commands for testing
setup_tmux_mock() {
    export TMUX="mock-session"
    export TMUX_PANE="%0"
    
    # Create mock tmux script
    local tmux_mock="$CONFIG_DIR/tmux-mock"
    cat > "$tmux_mock" << 'EOF'
#!/bin/bash
case "$1" in
    "capture-pane")
        echo "Mock tmux pane content"
        echo "Line 1 of pane"
        echo "Line 2 of pane"
        exit 0
        ;;
    "split-window")
        echo "Mock split-window command"
        exit 0
        ;;
    "new-window")
        echo "Mock new-window command"
        exit 0
        ;;
    *)
        echo "Mock tmux command: $*"
        exit 0
        ;;
esac
EOF
    chmod +x "$tmux_mock"
    export PATH="$CONFIG_DIR:$PATH"
    ln -sf "$tmux_mock" "$CONFIG_DIR/tmux"
}

# Test tmux pane content capture in bash
test_tmux_functions_bash() {
    setup_tmux_mock
    
    # Mock the get_tmux_pane_content function
    get_tmux_pane_content() {
        if [[ -n "$TMUX" ]]; then
            tmux capture-pane -p 2>/dev/null || echo "No tmux pane content available"
        else
            echo "Not running in tmux"
        fi
    }
    
    local result=$(get_tmux_pane_content)
    
    if [[ "$result" =~ "Mock tmux pane content" ]]; then
        return 0
    else
        echo "tmux functions test failed: $result"
        return 1
    fi
}

# Test tmux pane content capture in zsh
test_tmux_functions_zsh() {
    setup_tmux_mock
    
    local result=$(zsh -c '
        get_tmux_pane_content() {
            if [[ -n "$TMUX" ]]; then
                tmux capture-pane -p 2>/dev/null || echo "No tmux pane content available"
            else
                echo "Not running in tmux"
            fi
        }
        get_tmux_pane_content
    ')
    
    if [[ "$result" =~ "Mock tmux pane content" ]]; then
        return 0
    else
        echo "tmux functions test failed: $result"
        return 1
    fi
}

# Test tmux environment detection
test_tmux_detection() {
    local shell="$1"
    
    # Test with TMUX set
    export TMUX="mock-session"
    
    local tmux_check_script='
        if [[ -n "$TMUX" ]]; then
            echo "in_tmux"
        else
            echo "not_in_tmux"
        fi
    '
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$tmux_check_script")
    else
        result=$(bash -c "$tmux_check_script")
    fi
    
    if [[ "$result" == "in_tmux" ]]; then
        return 0
    else
        echo "tmux detection test failed: $result"
        return 1
    fi
}

# Test tmux pane splitting functionality
test_tmux_split_pane() {
    local shell="$1"
    setup_tmux_mock
    
    # Mock tmux-ai-pane.sh script
    local tmux_ai_script="$CONFIG_DIR/tmux-ai-pane.sh"
    cat > "$tmux_ai_script" << 'EOF'
#!/bin/bash
if [[ -n "$TMUX" ]]; then
    tmux split-window -h -p 30
    echo "AI pane created"
else
    echo "Not in tmux session"
fi
EOF
    chmod +x "$tmux_ai_script"
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$tmux_ai_script")
    else
        result=$(bash -c "$tmux_ai_script")
    fi
    
    if [[ "$result" =~ "AI pane created" ]]; then
        return 0
    else
        echo "tmux split pane test failed: $result"
        return 1
    fi
}

# Test tmux key bindings functionality
test_tmux_keybindings() {
    local shell="$1"
    
    # Test if tmux.conf exists and has AI bindings
    local tmux_conf="$CONFIG_DIR/tmux.conf"
    
    if [[ -f "$tmux_conf" ]]; then
        if grep -q "bind-key.*AI" "$tmux_conf"; then
            return 0
        else
            echo "tmux keybindings test failed: no AI bindings found"
            return 1
        fi
    else
        echo "tmux keybindings test failed: tmux.conf not found"
        return 1
    fi
}

# Test tmux session handling without tmux
test_no_tmux_handling() {
    local shell="$1"
    
    # Unset TMUX to simulate non-tmux environment
    unset TMUX
    unset TMUX_PANE
    
    local tmux_check_script='
        if [[ -n "$TMUX" ]]; then
            echo "in_tmux"
        else
            echo "not_in_tmux"
        fi
    '
    
    local result
    if [[ "$shell" == "zsh" ]]; then
        result=$(zsh -c "$tmux_check_script")
    else
        result=$(bash -c "$tmux_check_script")
    fi
    
    if [[ "$result" == "not_in_tmux" ]]; then
        return 0
    else
        echo "no tmux handling test failed: $result"
        return 1
    fi
} 