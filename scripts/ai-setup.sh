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
    echo "1. OpenAI (GPT-3.5/GPT-4)"
    echo "2. Anthropic (Claude)"
    echo "3. Google (Gemini)"
    echo "4. Ollama (Local)"
    echo "5. Configure workflow settings"
    echo "6. View current configuration"
    echo "7. Test AI integration"
    echo "0. Exit"
    echo
}

# Generic provider setup function
setup_provider() {
    local provider_key="$1"
    local display_name="$2"
    local default_model="$3"
    local use_api_key="$4"  # true/false
    local api_key_prompt="$5"
    local host_prompt="$6"
    local default_host="$7"
    
    echo -e "${GREEN}Setting up $display_name...${NC}"
    read -p "Enable $display_name provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        # Disable the provider while preserving existing configuration
        jq --arg provider "$provider_key" \
           '.providers[$provider] = (.providers[$provider] // {}) | .providers[$provider].enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}$display_name provider disabled (configuration preserved).${NC}"
    else
        # Enable and configure the provider
        local config_obj='{"enabled": true}'
        
        # Always prompt for model
        read -p "Enter model (default: $default_model): " model
        model=${model:-$default_model}
        
        # Only prompt for host if host_prompt is not empty
        if [[ -n "$host_prompt" ]]; then
            read -p "$host_prompt (default: $default_host): " host
            host=${host:-$default_host}
        fi
        
        if [[ "$use_api_key" == "true" ]]; then
            read -p "$api_key_prompt: " -s api_key
            echo
            
            if [[ -n "$host" ]]; then
                jq --arg provider "$provider_key" --arg key "$api_key" --arg model "$model" --arg host "$host" \
                   '.providers[$provider] = {"api_key": $key, "model": $model, "host": $host, "enabled": true}' \
                   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            else
                jq --arg provider "$provider_key" --arg key "$api_key" --arg model "$model" \
                   '.providers[$provider] = {"api_key": $key, "model": $model, "enabled": true}' \
                   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            fi
        else
            if [[ -n "$host" ]]; then
                jq --arg provider "$provider_key" --arg host "$host" --arg model "$model" \
                   '.providers[$provider] = {"host": $host, "model": $model, "enabled": true}' \
                   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            else
                jq --arg provider "$provider_key" --arg model "$model" \
                   '.providers[$provider] = {"model": $model, "enabled": true}' \
                   "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            fi
        fi
        
        echo -e "${GREEN}$display_name configured and enabled successfully!${NC}"
    fi
}

# Provider-specific wrapper functions
setup_openai() {
    setup_provider "openai" "OpenAI" "gpt-3.5-turbo" "true" "Enter your OpenAI API key" "" ""
}

setup_anthropic() {
    setup_provider "anthropic" "Anthropic" "claude-3-haiku-20240307" "true" "Enter your Anthropic API key" "" ""
}

setup_google() {
    setup_provider "google" "Google Gemini" "gemini-2.5-pro" "true" "Enter your Google AI API key" "" ""
}

setup_ollama() {
    setup_provider "ollama" "Ollama (Local)" "llama2" "false" "" "Enter Ollama host" "http://localhost:11434"
}

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
        1) setup_openai ;;
        2) setup_anthropic ;;
        3) setup_google ;;
        4) setup_ollama ;;
        5) setup_workflow ;;
        6) view_config ;;
        7) test_ai ;;
        0) echo -e "${GREEN}Setup complete!${NC}"; break ;;
        *) echo -e "${RED}Invalid option. Please try again.${NC}" ;;
    esac
    echo
done 