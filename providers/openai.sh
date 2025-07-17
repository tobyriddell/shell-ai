#!/bin/bash
# OpenAI Provider for Shell AI Integration

call_openai() {
    local provider_config="$1"
    local prompt="$2"
    
    # Extract parameters from config
    local api_key model
    api_key=$(echo "$provider_config" | jq -r '.api_key')
    model=$(echo "$provider_config" | jq -r '.model')
    
    curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [
                {\"role\": \"user\", \"content\": $(echo "$prompt" | jq -R -s .)}
            ],
            \"max_tokens\": 2000,
            \"temperature\": 0.7
        }" | jq -r '.choices[0].message.content // .error.message // "Error: Invalid response"'
}

setup_openai() {
    echo -e "${GREEN}Setting up OpenAI...${NC}"
    read -p "Enable OpenAI provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        # Disable the provider while preserving existing configuration
        jq '.providers.openai = (.providers.openai // {}) | .providers.openai.enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}OpenAI provider disabled (configuration preserved).${NC}"
    else
        # Enable and configure the provider
        read -p "Enter model (default: gpt-3.5-turbo): " model
        model=${model:-gpt-3.5-turbo}
        
        read -p "Enter your OpenAI API key: " -s api_key
        echo
        
        jq --arg key "$api_key" --arg model "$model" \
           '.providers.openai = {"api_key": $key, "model": $model, "enabled": true}' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        echo -e "${GREEN}OpenAI configured and enabled successfully!${NC}"
    fi
}

# Provider metadata
PROVIDER_NAME="OpenAI"
PROVIDER_DESCRIPTION="OpenAI (GPT-3.5/GPT-4)" 