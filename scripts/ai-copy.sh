#!/bin/bash

CONFIG_DIR="$HOME/.config/shell-ai"
RESPONSE_FILE="$CONFIG_DIR/last_response.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
# Additional colors for pane selector
BOLD='\033[1m'
DIM='\033[2m'
REVERSE='\033[7m'

if [[ ! -f "$RESPONSE_FILE" ]]; then
    echo -e "${RED}No AI response found. Run an AI query first.${NC}"
    exit 1
fi

# Extract potential commands from the response
extract_commands() {
    local in_code_block=false
    local commands=""
    local line
    local debug_mode=${1:-false}
    
    # Process each line to find code blocks and extract commands
    while IFS= read -r line; do
        if [[ "$debug_mode" == "true" ]]; then
            echo "DEBUG: Processing line: '$line'" >&2
        fi
        
        # Check for code block start/end
        if [[ "$line" =~ ^\`\`\`.*$ ]]; then
            if [[ "$in_code_block" == "true" ]]; then
                in_code_block=false
                if [[ "$debug_mode" == "true" ]]; then
                    echo "DEBUG: Code block END" >&2
                fi
            else
                in_code_block=true
                if [[ "$debug_mode" == "true" ]]; then
                    echo "DEBUG: Code block START" >&2
                fi
            fi
            continue
        fi
        
        # If we're in a code block, capture the line
        if [[ "$in_code_block" == "true" ]]; then
            # Skip empty lines
            if [[ -n "$(echo "$line" | tr -d '[:space:]')" ]]; then
                if [[ "$debug_mode" == "true" ]]; then
                    echo "DEBUG: Adding code block line: '$line'" >&2
                fi
                commands+="$line"$'\n'
            fi
        # If not in code block, look for shell-like patterns
        elif [[ "$line" =~ '^\$[[:space:]]*(.*)$' ]]; then
            # Lines starting with $ (shell prompt)
            local cmd="${BASH_REMATCH[1]}"
            if [[ -n "$(echo "$cmd" | tr -d '[:space:]')" ]]; then
                if [[ "$debug_mode" == "true" ]]; then
                    echo "DEBUG: Adding shell prompt line: '$cmd'" >&2
                fi
                commands+="$cmd"$'\n'
            fi
        elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+[[:space:]]*=.*) ]]; then
            # Variable assignments
            local assignment="${BASH_REMATCH[1]}"
            if [[ "$debug_mode" == "true" ]]; then
                echo "DEBUG: Adding assignment: '$assignment'" >&2
            fi
            commands+="$assignment"$'\n'
        fi
    done < "$RESPONSE_FILE"
    
    # Remove trailing newline and output
    echo -n "$commands" | sed '/^[[:space:]]*$/d'
}

show_menu() {
    echo -e "${YELLOW}AI Response Actions:${NC}"
    echo "1. Show full response"
    echo "2. Copy commands to current shell (same environment)"
    echo "3. Send to tmux pane"
    echo "4. Extract and show commands only"
    echo "5. Debug command extraction"
    echo "0. Exit"
    echo
}

copy_to_shell() {
    local commands
    commands=$(extract_commands)
    
    if [[ -z "$commands" ]]; then
        echo -e "${RED}No commands found in AI response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Extracted commands:${NC}"
    echo "$commands"
    echo
    read -p "Copy these commands to your shell? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # If in tmux, send to current pane with clean interface management
        if [[ -n "$TMUX" ]]; then
            # Convert commands to array for safe processing
            local cmd_array=()
            while IFS= read -r cmd; do
                if [[ -n "$cmd" ]]; then
                    cmd_array+=("$cmd")
                fi
            done <<< "$commands"
            
            echo -e "${GREEN}Commands to execute in current shell:${NC}"
            printf '%s\n' "${cmd_array[@]}"
            echo
            read -p "Press Enter to execute these commands..." -r
            
            # Clear screen and execute commands directly
            # clear
            echo -e "${YELLOW}Executing commands in current shell...${NC}"
            echo
            
            # Execute each command directly in current shell
            for cmd in "${cmd_array[@]}"; do
                echo -e "${CYAN}> $cmd${NC}"
                eval "$cmd"
                echo
            done
            
            echo
            echo -e "${GREEN}Commands executed!${NC}" 
            
            # Clear any buffered input to prevent "Invalid option" errors
            while read -r -t 0; do
                read -r > /dev/null 2>&1
            done
            
            echo -e "${CYAN}Press Enter to return to ai-copy menu...${NC}"
            read -r
            
            # Clear any remaining buffered input one more time
            while read -r -t 0; do
                read -r > /dev/null 2>&1
            done
            
            # clear
        else
            # Write to a temp script for execution
            local temp_script="/tmp/ai_commands_$$"
            echo "$commands" > "$temp_script"
            chmod +x "$temp_script"
            echo -e "${YELLOW}Commands saved to $temp_script${NC}"
            echo -e "${YELLOW}Run: source $temp_script${NC}"
            echo
            read -p "Press 'x' to exit ai-copy, or any other key to continue: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Xx]$ ]]; then
                exit 0
            fi
        fi
    fi
}

# Get panes information in array format (fallback function)
get_panes_info() {
    local panes_info=()
    local line
    while IFS= read -r line; do
        panes_info+=("$line")
    done < <(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}|#{pane_title}|#{t:last-used}|#{pane_active}")
    printf '%s\n' "${panes_info[@]}"
}

# Get the last-used pane index (fallback function)
get_last_used_pane_index() {
    local panes_info=()
    local current_pane_id=$(tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}")
    local last_used_time=0
    local last_used_index=0
    local index=0
    
    while IFS= read -r line; do
        local pane_id=$(echo "$line" | cut -d'|' -f1)
        local last_used=$(echo "$line" | cut -d'|' -f3)
        local is_active=$(echo "$line" | cut -d'|' -f4)
        
        # Skip current pane, prioritize recently used panes
        if [[ "$pane_id" != "$current_pane_id" ]]; then
            if [[ "$is_active" == "1" ]] || [[ "$last_used" -gt "$last_used_time" ]]; then
                last_used_time="$last_used"
                last_used_index="$index"
            fi
        fi
        ((index++))
    done < <(get_panes_info)
    
    echo "$last_used_index"
}

# Display panes with selection highlighting (fallback function)
display_panes() {
    local selected_index=$1
    local panes_info=()
    local index=0
    
    echo -e "${YELLOW}Select target tmux pane:${NC}" >&2
    echo -e "${DIM}Use ↑↓/WS/KJ to navigate, Enter to select, q to cancel${NC}" >&2
    echo >&2
    
    while IFS= read -r line; do
        local pane_id=$(echo "$line" | cut -d'|' -f1)
        local pane_title=$(echo "$line" | cut -d'|' -f2)
        local display_line="$pane_id - $pane_title"
        
        if [[ $index -eq $selected_index ]]; then
            echo -e "  ${BOLD}${REVERSE}> $display_line${NC}" >&2
        else
            echo -e "    $display_line" >&2
        fi
        ((index++))
    done < <(get_panes_info)
    echo >&2
}

# Fallback shell-based pane selector
fallback_pane_selector() {
    local panes_info=()
    mapfile -t panes_info < <(get_panes_info)
    local pane_count=${#panes_info[@]}
    
    if [[ $pane_count -eq 0 ]]; then
        echo -e "${RED}No tmux panes found${NC}" >&2
        return 1
    fi
    
    local selected_index
    selected_index=$(get_last_used_pane_index)
    
    # Ensure selected_index is within bounds
    if [[ $selected_index -ge $pane_count ]]; then
        selected_index=0
    fi
    
    # Clear any buffered input to prevent immediate selection
    while read -r -t 0; do
        read -r > /dev/null 2>&1
    done
    
    while true; do
        clear >&2
        display_panes "$selected_index"
        
        # Small delay to ensure display is rendered
        sleep 0.05
        
        # Read input (handle arrow keys properly)
        read -rsn1 key
        
        # Handle escape sequences (arrow keys)
        if [[ "$key" == $'\033' ]]; then
            read -rsn2 -t 0.01 key_seq || key_seq=""
            key="$key$key_seq"
        fi
        
        case "$key" in
            # Arrow keys
            $'\033[A') # Up arrow
                ((selected_index--))
                if [[ $selected_index -lt 0 ]]; then
                    selected_index=$((pane_count - 1))
                fi
                ;;
            $'\033[B') # Down arrow
                ((selected_index++))
                if [[ $selected_index -ge $pane_count ]]; then
                    selected_index=0
                fi
                ;;
            $'\033[D') # Left arrow (same as up)
                ((selected_index--))
                if [[ $selected_index -lt 0 ]]; then
                    selected_index=$((pane_count - 1))
                fi
                ;;
            $'\033[C') # Right arrow (same as down)
                ((selected_index++))
                if [[ $selected_index -ge $pane_count ]]; then
                    selected_index=0
                fi
                ;;
            # WASD navigation
            'w'|'W'|'k'|'K') # Up
                ((selected_index--))
                if [[ $selected_index -lt 0 ]]; then
                    selected_index=$((pane_count - 1))
                fi
                ;;
            's'|'S'|'j'|'J') # Down
                ((selected_index++))
                if [[ $selected_index -ge $pane_count ]]; then
                    selected_index=0
                fi
                ;;
            'a'|'A'|'h'|'H') # Left (same as up)
                ((selected_index--))
                if [[ $selected_index -lt 0 ]]; then
                    selected_index=$((pane_count - 1))
                fi
                ;;
            'd'|'D'|'l'|'L') # Right (same as down)
                ((selected_index++))
                if [[ $selected_index -ge $pane_count ]]; then
                    selected_index=0
                fi
                ;;
            # Enter to select
            '')
                local selected_pane_info="${panes_info[$selected_index]}"
                local selected_pane_id=$(echo "$selected_pane_info" | cut -d'|' -f1)
                echo "$selected_pane_id"
                return 0
                ;;
            # Quit
            'q'|'Q'|$'\004') # q, Q, or Ctrl+D
                return 1
                ;;
        esac
    done
}

# Interactive pane selector using Rust binary with fallback
interactive_pane_selector() {
    # Look for the tmux-selector binary in multiple locations
    local tmux_selector=""
    
    # Check if we have the binary in the expected locations
    if [[ -x "$CONFIG_DIR/../tmux-selector/target/release/tmux-selector" ]]; then
        tmux_selector="$CONFIG_DIR/../tmux-selector/target/release/tmux-selector"
    elif [[ -x "$CONFIG_DIR/tmux-selector" ]]; then
        tmux_selector="$CONFIG_DIR/tmux-selector"
    elif command -v tmux-selector >/dev/null 2>&1; then
        tmux_selector="tmux-selector"
    else
        # Binary not found, use fallback
        fallback_pane_selector
        return $?
    fi
    
    # Try using the Rust binary first
    # The binary now uses stderr for interactive display and stdout for the result
    local result
    result=$("$tmux_selector" 2>/dev/tty)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$result" && ! "$result" =~ "Error:" ]]; then
        echo "$result"
        return 0
    fi
    
    # Rust binary failed or returned empty result, use fallback
    fallback_pane_selector
    return $?
}

select_pane() {
    if [[ -z "$TMUX" ]]; then
        echo -e "${RED}Not running in tmux${NC}" >&2
        return 1
    fi

    # Set global variable for use in send_to_pane
    target_pane=$(interactive_pane_selector)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$target_pane" ]]; then
        echo -e "${RED}Pane selection cancelled${NC}" >&2
        return 1
    fi

    if [[ -n "$target_pane" ]]; then
        # Check if target pane is the current pane
        local current_pane_id=$(tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}")
        local is_current_pane=false
        if [[ "$target_pane" == "$current_pane_id" ]] || [[ "$target_pane" == "$TMUX_PANE" ]]; then
            is_current_pane=true
        fi

        if [[ "$is_current_pane" == "true" ]]; then
            echo -e "${GREEN}Target pane is the current pane.${NC}" >&2
            # Set global flag for current pane
            target_is_current_pane=true
            return 0
        fi

        echo -e "${GREEN}Selected pane: ${BOLD}$target_pane${NC}" >&2
        target_is_current_pane=false
        return 0
    else
        echo -e "${RED}Invalid pane format or not found.${NC}" >&2
        return 1
    fi
}

send_to_pane() {
    if [[ -z "$TMUX" ]]; then
        echo -e "${RED}Not running in tmux${NC}" >&2
        return 1
    fi
    
    if ! select_pane; then
        return 1
    fi
    
    local commands
    commands=$(extract_commands)
    
    if [[ -n "$commands" ]]; then
        # Convert commands to array to avoid read interference
        local cmd_array=()
        while IFS= read -r cmd; do
            if [[ -n "$cmd" ]]; then
                cmd_array+=("$cmd")
            fi
        done <<< "$commands"
        
        # Process each command from array
        for cmd in "${cmd_array[@]}"; do
            # Selectively escape only problematic sequences for display
            local display_cmd="$cmd"
            display_cmd="${display_cmd//\\n/\\\\n}"    # \n -> \\n
            display_cmd="${display_cmd//\\t/\\\\t}"    # \t -> \\t
            display_cmd="${display_cmd//\\r/\\\\r}"    # \r -> \\r
            display_cmd="${display_cmd//\\\\/\\\\\\\\}" # \\ -> \\\\
            printf "${CYAN}Command: ${NC}%s\n" "$display_cmd" 
            read -p "Send this command? Press Enter to send, 's' to skip: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                # Send complete command + Enter in one operation (using original unescaped command)
                tmux send-keys -t "$target_pane" "$cmd" C-m
            fi
        done
        
        if [[ "$target_is_current_pane" == "true" ]]; then
            echo -e "${GREEN}Commands sent to current pane! Exiting ai-copy to avoid conflicts...${NC}"
            sleep 1
            exit 0
        else
            echo -e "${GREEN}Commands sent to target pane${NC}"
            echo
            read -p "Commands are executing. Press 'x' to exit ai-copy, or any other key to continue: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Xx]$ ]]; then
                exit 0
            fi
        fi
    else
        echo -e "${RED}No commands found in AI response${NC}" >&2
        return 1
    fi
}

# Main menu
while true; do
    show_menu
    read -p "Select an option: " choice
    
    case $choice in
        1) 
            echo -e "${GREEN}Full AI Response:${NC}"
            cat "$RESPONSE_FILE"
            echo
            ;;
        2) copy_to_shell ;;
        3) send_to_pane ;;
        4) 
            echo -e "${GREEN}Extracted Commands:${NC}"
            extract_commands
            echo
            ;;
        5)
            echo -e "${GREEN}Debug Command Extraction:${NC}"
            extract_commands true
            echo
            ;;
        0) break ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done 