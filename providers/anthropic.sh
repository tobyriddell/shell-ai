#!/bin/bash
# Anthropic Provider for Shell AI Integration

call_anthropic() {
    local provider_config="$1"
    local prompt="$2"
    
    # Extract parameters from config
    local api_key model
    api_key=$(echo "$provider_config" | jq -r '.api_key')
    model=$(echo "$provider_config" | jq -r '.model')
    
    curl -s -X POST "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $api_key" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d "{
            \"model\": \"$model\",
            \"max_tokens\": 2000,
            \"messages\": [
                {\"role\": \"user\", \"content\": $(echo "$prompt" | jq -R -s .)}
            ]
        }" | jq -r '.content[0].text // .error.message // "Error: Invalid response"'
}

setup_anthropic() {
    echo -e "${GREEN}Setting up Anthropic...${NC}"
    read -p "Enable Anthropic provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        # Disable the provider while preserving existing configuration
        jq '.providers.anthropic = (.providers.anthropic // {}) | .providers.anthropic.enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}Anthropic provider disabled (configuration preserved).${NC}"
    else
        # Enable and configure the provider
        read -p "Enter model (default: claude-3-haiku-20240307): " model
        model=${model:-claude-3-haiku-20240307}
        
        read -p "Enter your Anthropic API key: " -s api_key
        echo
        
        jq --arg key "$api_key" --arg model "$model" \
           '.providers.anthropic = {"api_key": $key, "model": $model, "enabled": true}' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        echo -e "${GREEN}Anthropic configured and enabled successfully!${NC}"
    fi
}

# Provider metadata
PROVIDER_NAME="Anthropic"
PROVIDER_DESCRIPTION="Anthropic (Claude)" 