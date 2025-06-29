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

setup_openai() {
    echo -e "${GREEN}Setting up OpenAI...${NC}"
    read -p "Enter your OpenAI API key: " -s api_key
    echo
    read -p "Enter model (default: gpt-3.5-turbo): " model
    model=${model:-gpt-3.5-turbo}
    
    # Update config
    jq --arg key "$api_key" --arg model "$model" \
       '.providers.openai = {"api_key": $key, "model": $model, "enabled": true}' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}OpenAI configured successfully!${NC}"
}

setup_anthropic() {
    echo -e "${GREEN}Setting up Anthropic...${NC}"
    read -p "Enter your Anthropic API key: " -s api_key
    echo
    read -p "Enter model (default: claude-3-haiku-20240307): " model
    model=${model:-claude-3-haiku-20240307}
    
    jq --arg key "$api_key" --arg model "$model" \
       '.providers.anthropic = {"api_key": $key, "model": $model, "enabled": true}' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Anthropic configured successfully!${NC}"
}

setup_google() {
    echo -e "${GREEN}Setting up Google Gemini...${NC}"
    read -p "Enter your Google AI API key: " -s api_key
    echo
    read -p "Enter model (default: gemini-pro): " model
    model=${model:-gemini-pro}
    
    jq --arg key "$api_key" --arg model "$model" \
       '.providers.google = {"api_key": $key, "model": $model, "enabled": true}' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Google Gemini configured successfully!${NC}"
}

setup_ollama() {
    echo -e "${GREEN}Setting up Ollama (Local)...${NC}"
    read -p "Enter Ollama host (default: http://localhost:11434): " host
    host=${host:-http://localhost:11434}
    read -p "Enter model (default: llama2): " model
    model=${model:-llama2}
    
    jq --arg host "$host" --arg model "$model" \
       '.providers.ollama = {"host": $host, "model": $model, "enabled": true}' \
       "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}Ollama configured successfully!${NC}"
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
    echo "Auto-launch ai-copy after AI responses: $current_auto_copy"
    echo "Prompt before auto-launching ai-copy: $current_auto_copy_prompt"
    echo
    
    read -p "Auto-launch ai-copy after AI responses? (y/N): " auto_copy_choice
    if [[ $auto_copy_choice =~ ^[Yy]$ ]]; then
        auto_copy="true"
        read -p "Prompt before auto-launching ai-copy? (Y/n): " prompt_choice
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