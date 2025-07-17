#!/bin/bash
# Google Provider for Shell AI Integration

call_google() {
    local provider_config="$1"
    local prompt="$2"
    
    # Extract parameters from config
    local api_key model
    api_key=$(echo "$provider_config" | jq -r '.api_key')
    model=$(echo "$provider_config" | jq -r '.model')
    
    curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"contents\": [{
                \"parts\": [{\"text\": $(echo "$prompt" | jq -R -s .)}]
            }]
        }" | jq -r '.candidates[0].content.parts[0].text // .error.message // "Error: Invalid response"'
}

setup_google() {
    echo -e "${GREEN}Setting up Google Gemini...${NC}"
    read -p "Enable Google Gemini provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        # Disable the provider while preserving existing configuration
        jq '.providers.google = (.providers.google // {}) | .providers.google.enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}Google Gemini provider disabled (configuration preserved).${NC}"
    else
        # Enable and configure the provider
        read -p "Enter model (default: gemini-2.5-pro): " model
        model=${model:-gemini-2.5-pro}
        
        read -p "Enter your Google AI API key: " -s api_key
        echo
        
        jq --arg key "$api_key" --arg model "$model" \
           '.providers.google = {"api_key": $key, "model": $model, "enabled": true}' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        echo -e "${GREEN}Google Gemini configured and enabled successfully!${NC}"
    fi
}

# Provider metadata
PROVIDER_NAME="Google"
PROVIDER_DESCRIPTION="Google (Gemini)" 