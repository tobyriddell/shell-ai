#!/bin/bash

CONFIG_DIR="$HOME/.config/shell-ai"
RESPONSE_FILE="$CONFIG_DIR/last_response.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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

send_to_pane() {
    if [[ -z "$TMUX" ]]; then
        echo -e "${RED}Not running in tmux${NC}"
        return 1
    fi
    
    # List available panes
    echo -e "${YELLOW}Available tmux panes:${NC}"
    tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} - #{pane_title}"
    echo
    
    read -p "Enter target pane (format: session:window.pane): " target_pane
    
    if [[ -n "$target_pane" ]]; then
        local commands
        commands=$(extract_commands)
        
        # Check if target pane is the current pane
        local current_pane_id=$(tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}")
        local is_current_pane=false
        if [[ "$target_pane" == "$current_pane_id" ]] || [[ "$target_pane" == "$TMUX_PANE" ]]; then
            is_current_pane=true
        fi
        
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
            
            if [[ "$is_current_pane" == "true" ]]; then
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
            echo -e "${RED}No commands found in AI response${NC}"
            return 1
        fi
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