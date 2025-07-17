#!/bin/bash

CONFIG_DIR="$HOME/.config/shell-ai"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Shell AI Setup ===${NC}"
echo

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Initialize config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"providers": {}}' > "$CONFIG_FILE"
fi

show_menu() {
    echo -e "${YELLOW}Available AI Providers:${NC}"
    
    # Dynamically discover available providers
    local i=1
    declare -g -A PROVIDER_MAP
    
    for provider_file in "$PROVIDERS_DIR"/*.sh; do
        if [[ -f "$provider_file" ]]; then
            provider_name=$(basename "$provider_file" .sh)
            
            # Check if setup function exists
            if declare -f "setup_$provider_name" >/dev/null 2>&1; then
                # Get provider description by sourcing the file in a subshell
                provider_description=$(
                    source "$provider_file"
                    echo "${PROVIDER_DESCRIPTION:-$provider_name}"
                )
                
                echo "$i. $provider_description"
                PROVIDER_MAP[$i]="$provider_name"
                ((i++))
            fi
        fi
    done
    
    echo "$i. Configure workflow settings"
    PROVIDER_MAP[$i]="workflow"
    ((i++))
    
    echo "$i. View current configuration"
    PROVIDER_MAP[$i]="view"
    ((i++))
    
    echo "$i. Test AI integration"
    PROVIDER_MAP[$i]="test"
    
    echo "0. Exit"
    echo
}

# Get script directory for loading providers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="$SCRIPT_DIR/providers"

# Load AI providers from providers directory
load_providers() {
    local providers_dir="$1"
    
    if [[ ! -d "$providers_dir" ]]; then
        echo -e "${RED}Error: Providers directory not found: $providers_dir${NC}" >&2
        return 1
    fi
    
    # Load all provider files
    for provider_file in "$providers_dir"/*.sh; do
        if [[ -f "$provider_file" ]]; then
            source "$provider_file"
        fi
    done
}

# Load providers at startup
load_providers "$PROVIDERS_DIR"

setup_workflow() {
    echo -e "${GREEN}Configuring workflow settings...${NC}"
    
    # Ensure settings section exists
    if ! jq -e '.settings' "$CONFIG_FILE" >/dev/null 2>&1; then
        jq '.settings = {"auto_copy": false, "auto_copy_prompt": true}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
    
    local current_auto_copy=$(jq -r '.settings.auto_copy // false' "$CONFIG_FILE")
    local current_auto_copy_prompt=$(jq -r '.settings.auto_copy_prompt // true' "$CONFIG_FILE")
    
    echo
    echo -e "${YELLOW}Current workflow settings:${NC}"
    echo "Auto-launch ai-copy after AI responses (tmux only): $current_auto_copy"
    echo "Prompt before auto-launching ai-copy (tmux only): $current_auto_copy_prompt"
    echo
    
    read -p "Auto-launch ai-copy after AI responses (tmux only)? (y/N): " auto_copy_choice
    if [[ $auto_copy_choice =~ ^[Yy]$ ]]; then
        auto_copy="true"
        read -p "Prompt before auto-launching ai-copy (tmux only)? (Y/n): " prompt_choice
        if [[ $prompt_choice =~ ^[Nn]$ ]]; then
            auto_copy_prompt="false"
        else
            auto_copy_prompt="true"
        fi
    else
        auto_copy="false"
        auto_copy_prompt="true"
    fi
    
    # Update config
    jq --arg auto_copy "$auto_copy" --arg auto_copy_prompt "$auto_copy_prompt" \
       '.settings.auto_copy = ($auto_copy == "true") | .settings.auto_copy_prompt = ($auto_copy_prompt == "true")' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Workflow settings updated!${NC}"
    echo "Auto-launch ai-copy: $auto_copy"
    if [[ "$auto_copy" == "true" ]]; then
        echo "Prompt before launching: $auto_copy_prompt"
    fi
}

view_config() {
    echo -e "${YELLOW}Current Configuration:${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo
        echo -e "${BLUE}AI Providers:${NC}"
        jq -r '.providers | to_entries[] | "\(.key): enabled=\(.value.enabled // false)"' "$CONFIG_FILE"
        
        echo
        echo -e "${BLUE}Workflow Settings:${NC}"
        local auto_copy=$(jq -r '.settings.auto_copy // false' "$CONFIG_FILE")
        local auto_copy_prompt=$(jq -r '.settings.auto_copy_prompt // true' "$CONFIG_FILE")
        echo "Auto-launch ai-copy: $auto_copy"
        if [[ "$auto_copy" == "true" ]]; then
            echo "Prompt before launching: $auto_copy_prompt"
        fi
    else
        echo "No configuration found."
    fi
}

test_ai() {
    echo -e "${YELLOW}Testing AI integration...${NC}"
    ~/.config/shell-ai/ai-shell.sh --test
}

while true; do
    show_menu
    read -p "Select an option: " choice
    
    case $choice in
        0) echo -e "${GREEN}Setup complete!${NC}"; break ;;
        *)
            if [[ -n "${PROVIDER_MAP[$choice]:-}" ]]; then
                provider_choice="${PROVIDER_MAP[$choice]}"
                case "$provider_choice" in
                    "workflow") setup_workflow ;;
                    "view") view_config ;;
                    "test") test_ai ;;
                    *) 
                        # Call the provider's setup function
                        if declare -f "setup_$provider_choice" >/dev/null 2>&1; then
                            "setup_$provider_choice"
                        else
                            echo -e "${RED}Error: Setup function not found for $provider_choice${NC}"
                        fi
                        ;;
                esac
            else
                echo -e "${RED}Invalid option. Please try again.${NC}"
            fi
            ;;
    esac
    echo
done 