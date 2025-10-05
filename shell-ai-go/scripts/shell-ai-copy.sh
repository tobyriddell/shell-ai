#!/bin/bash

# shell-ai-copy.sh - Command extraction and tmux integration for shell-ai-go
# This script provides similar functionality to ai-copy.sh but works with the Go implementation

CONFIG_DIR="$HOME/.config/shell-ai"
RESPONSE_FILE="$CONFIG_DIR/last_response.txt"
SHELL_AI_GO_BINARY=""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
REVERSE='\033[7m'

# Find the shell-ai-go binary
find_shell_ai_go() {
    # Check various locations
    local locations=(
        "$CONFIG_DIR/shell-ai-go"
        "$HOME/.local/bin/shell-ai"
        "$(dirname "$0")/../build/shell-ai"
        "$(which shell-ai 2>/dev/null)"
    )
    
    for location in "${locations[@]}"; do
        if [[ -x "$location" ]]; then
            SHELL_AI_GO_BINARY="$location"
            return 0
        fi
    done
    
    echo -e "${RED}Error: shell-ai-go binary not found${NC}" >&2
    echo -e "${YELLOW}Please build it first with: make build${NC}" >&2
    return 1
}

# Check if we have a response file or if we should create one
check_response_file() {
    if [[ ! -f "$RESPONSE_FILE" ]]; then
        echo -e "${YELLOW}No recent AI response found.${NC}"
        echo -e "${CYAN}Would you like to ask a question first? [y/N]:${NC}"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Enter your question:${NC}"
            read -r question
            if [[ -n "$question" ]]; then
                echo -e "${YELLOW}Asking AI...${NC}"
                "$SHELL_AI_GO_BINARY" ask "$question"
                if [[ $? -eq 0 && -f "$RESPONSE_FILE" ]]; then
                    return 0
                else
                    echo -e "${RED}Failed to get AI response${NC}"
                    return 1
                fi
            fi
        fi
        return 1
    fi
    return 0
}

# Extract commands using shell-ai-go's response parser
extract_commands() {
    if [[ ! -f "$RESPONSE_FILE" ]]; then
        echo -e "${RED}No response file found${NC}" >&2
        return 1
    fi

    # Use a simple extraction method similar to the original ai-copy.sh
    # Look for code blocks and shell prompts
    local commands=""
    local in_code_block=false
    local line
    
    while IFS= read -r line; do
        # Check for code block markers
        if [[ "$line" =~ ^\`\`\`.*$ ]]; then
            if [[ "$in_code_block" == "true" ]]; then
                in_code_block=false
            else
                in_code_block=true
            fi
            continue
        fi
        
        # If we're in a code block, capture the line
        if [[ "$in_code_block" == "true" ]]; then
            if [[ -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
                commands+="$line"$'\n'
            fi
        # Look for shell-like patterns outside code blocks
        elif [[ "$line" =~ ^\$[[:space:]]*(.*)$ ]]; then
            local cmd="${BASH_REMATCH[1]}"
            if [[ -n "$(echo "$cmd" | tr -d '[:space:]')" ]]; then
                commands+="$cmd"$'\n'
            fi
        fi
    done < "$RESPONSE_FILE"
    
    # Remove trailing newline and output
    echo -n "$commands" | sed '/^[[:space:]]*$/d'
}

# Show menu
show_menu() {
    echo -e "${YELLOW}Shell AI Go - Response Actions:${NC}"
    echo "1. Show full response"
    echo "2. Extract and show commands only"
    echo "3. Send commands to tmux pane"
    echo "4. Execute commands in current shell"
    echo "5. Start new AI conversation"
    echo "0. Exit"
    echo
}

# Show full response
show_response() {
    echo -e "${GREEN}Full AI Response:${NC}"
    cat "$RESPONSE_FILE"
    echo
}

# Show extracted commands
show_commands() {
    local commands
    commands=$(extract_commands)
    
    if [[ -z "$commands" ]]; then
        echo -e "${RED}No commands found in AI response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Extracted Commands:${NC}"
    echo "$commands"
    echo
}

# Execute commands in current shell
execute_commands() {
    local commands
    commands=$(extract_commands)
    
    if [[ -z "$commands" ]]; then
        echo -e "${RED}No commands found in AI response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Commands to execute:${NC}"
    echo "$commands"
    echo
    read -p "Execute these commands in current shell? [y/N]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Executing commands...${NC}"
        echo
        
        # Execute each command
        while IFS= read -r cmd; do
            if [[ -n "$cmd" ]]; then
                echo -e "${CYAN}> $cmd${NC}"
                eval "$cmd"
                echo
            fi
        done <<< "$commands"
        
        echo -e "${GREEN}Commands executed!${NC}"
    fi
}

# Send to tmux pane (using the Go binary's pane selector if available)
send_to_pane() {
    if [[ -z "$TMUX" ]]; then
        echo -e "${RED}Not running in tmux${NC}"
        return 1
    fi
    
    local commands
    commands=$(extract_commands)
    
    if [[ -z "$commands" ]]; then
        echo -e "${RED}No commands found in AI response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Commands to send:${NC}"
    echo "$commands"
    echo
    
    # Try to use the tmux-selector from the Go implementation or shell-ai
    local tmux_selector=""
    local go_selector="$(dirname "$SHELL_AI_GO_BINARY")/tmux-selector"
    local config_selector="$CONFIG_DIR/tmux-selector"
    
    if [[ -x "$go_selector" ]]; then
        tmux_selector="$go_selector"
    elif [[ -x "$config_selector" ]]; then
        tmux_selector="$config_selector"
    elif command -v tmux-selector >/dev/null 2>&1; then
        tmux_selector="tmux-selector"
    else
        echo -e "${YELLOW}No tmux-selector found, using fallback selection${NC}"
        use_fallback_selector "$commands"
        return $?
    fi
    
    echo -e "${CYAN}Select target tmux pane...${NC}"
    local target_pane
    target_pane=$("$tmux_selector" 2>/dev/tty)
    
    if [[ $? -ne 0 || -z "$target_pane" ]]; then
        echo -e "${RED}Pane selection cancelled${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Sending to pane: $target_pane${NC}"
    
    # Send each command
    while IFS= read -r cmd; do
        if [[ -n "$cmd" ]]; then
            echo -e "${CYAN}Sending: $cmd${NC}"
            read -p "Send this command? [Y/n/s(kip)]: " -n 1 -r
            echo
            case "$REPLY" in
                [Nn]) echo "Cancelled."; return 0 ;;
                [Ss]) echo "Skipped."; continue ;;
                *) 
                    tmux send-keys -t "$target_pane" "$cmd" C-m
                    echo "Sent."
                    ;;
            esac
        fi
    done <<< "$commands"
    
    echo -e "${GREEN}Commands sent to pane!${NC}"
}

# Fallback pane selector
use_fallback_selector() {
    local commands="$1"
    
    echo -e "${YELLOW}Available tmux panes:${NC}"
    tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} - #{pane_title}"
    echo
    
    read -p "Enter target pane ID (e.g., main:0.1): " target_pane
    
    if [[ -z "$target_pane" ]]; then
        echo -e "${RED}No pane selected${NC}"
        return 1
    fi
    
    # Validate pane exists
    if ! tmux has-session -t "${target_pane%.*}" 2>/dev/null; then
        echo -e "${RED}Invalid pane: $target_pane${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Sending to pane: $target_pane${NC}"
    
    # Send commands
    while IFS= read -r cmd; do
        if [[ -n "$cmd" ]]; then
            echo -e "${CYAN}Sending: $cmd${NC}"
            tmux send-keys -t "$target_pane" "$cmd" C-m
        fi
    done <<< "$commands"
    
    echo -e "${GREEN}Commands sent!${NC}"
}

# Start new conversation
start_conversation() {
    echo -e "${CYAN}Starting new AI conversation...${NC}"
    echo -e "${YELLOW}Enter 'Ctrl-D' to exit the conversation${NC}"
    echo
    "$SHELL_AI_GO_BINARY" interactive
}

# Main function
main() {
    # Find the shell-ai-go binary
    if ! find_shell_ai_go; then
        exit 1
    fi
    
    echo -e "${BOLD}Shell AI Go - Command Manager${NC}"
    echo -e "${DIM}Using: $SHELL_AI_GO_BINARY${NC}"
    echo
    
    # Check if we have a response file
    if ! check_response_file; then
        exit 1
    fi
    
    # Main menu loop
    while true; do
        show_menu
        read -p "Select an option: " choice
        
        case $choice in
            1) show_response ;;
            2) show_commands ;;
            3) send_to_pane ;;
            4) execute_commands ;;
            5) start_conversation ;;
            0) break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        if [[ $choice != 0 ]]; then
            echo
            read -p "Press Enter to continue..." -r
            echo
        fi
    done
    
    echo -e "${GREEN}Goodbye!${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
