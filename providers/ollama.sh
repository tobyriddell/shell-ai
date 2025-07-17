#!/bin/bash
# Ollama Provider for Shell AI Integration

call_ollama() {
    local provider_config="$1"
    local prompt="$2"
    
    # Extract parameters from config
    local host model
    host=$(echo "$provider_config" | jq -r '.host')
    model=$(echo "$provider_config" | jq -r '.model')
    
    curl -s -X POST "$host/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"prompt\": $(echo "$prompt" | jq -R -s .),
            \"stream\": false
        }" | jq -r '.response // .error // "Error: Invalid response"'
}

setup_ollama() {
    echo -e "${GREEN}Setting up Ollama (Local)...${NC}"
    read -p "Enable Ollama provider? (Y/n): " enable_choice
    
    if [[ $enable_choice =~ ^[Nn]$ ]]; then
        # Disable the provider while preserving existing configuration
        jq '.providers.ollama = (.providers.ollama // {}) | .providers.ollama.enabled = false' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "${YELLOW}Ollama provider disabled (configuration preserved).${NC}"
    else
        # Enable and configure the provider
        read -p "Enter model (default: llama2): " model
        model=${model:-llama2}
        
        read -p "Enter Ollama host (default: http://localhost:11434): " host
        host=${host:-http://localhost:11434}
        
        jq --arg host "$host" --arg model "$model" \
           '.providers.ollama = {"host": $host, "model": $model, "enabled": true}' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        echo -e "${GREEN}Ollama configured and enabled successfully!${NC}"
    fi
}

# Provider metadata
PROVIDER_NAME="Ollama"
PROVIDER_DESCRIPTION="Ollama (Local)" 