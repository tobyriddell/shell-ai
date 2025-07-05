#!/bin/bash

# Test configuration management

# Setup test config
setup_test_config() {
    local config_file="$CONFIG_DIR/config.json"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$config_file" << 'EOF'
{
    "providers": {
        "openai": {
            "enabled": true,
            "api_key": "test-key-openai",
            "model": "gpt-4",
            "endpoint": "https://api.openai.com/v1/chat/completions"
        },
        "anthropic": {
            "enabled": false,
            "api_key": "test-key-anthropic",
            "model": "claude-3-sonnet-20240229",
            "endpoint": "https://api.anthropic.com/v1/messages"
        }
    },
    "settings": {
        "max_history_lines": 50,
        "max_pane_lines": 100
    }
}
EOF
}

# Test config loading in bash
test_config_loading_bash() {
    setup_test_config
    
    # Test if jq can read the config
    local config_file="$CONFIG_DIR/config.json"
    local openai_enabled=$(jq -r '.providers.openai.enabled' "$config_file" 2>/dev/null)
    
    if [[ "$openai_enabled" == "true" ]]; then
        return 0
    else
        echo "Config loading test failed: openai_enabled=$openai_enabled"
        return 1
    fi
}

# Test config loading in zsh
test_config_loading_zsh() {
    setup_test_config
    
    # Test if jq can read the config in zsh context
    local config_file="$CONFIG_DIR/config.json"
    local anthropic_enabled=$(zsh -c "jq -r '.providers.anthropic.enabled' '$config_file'" 2>/dev/null)
    
    if [[ "$anthropic_enabled" == "false" ]]; then
        return 0
    else
        echo "Config loading test failed: anthropic_enabled=$anthropic_enabled"
        return 1
    fi
}

# Test config file validation
test_config_validation() {
    local shell="$1"
    setup_test_config
    
    local config_file="$CONFIG_DIR/config.json"
    
    # Test if config is valid JSON
    local validation_result
    if [[ "$shell" == "zsh" ]]; then
        validation_result=$(zsh -c "jq empty '$config_file'" 2>&1)
    else
        validation_result=$(bash -c "jq empty '$config_file'" 2>&1)
    fi
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        echo "Config validation test failed: $validation_result"
        return 1
    fi
}

# Test provider extraction
test_provider_extraction() {
    local shell="$1"
    setup_test_config
    
    local config_file="$CONFIG_DIR/config.json"
    local providers
    
    if [[ "$shell" == "zsh" ]]; then
        providers=$(zsh -c "jq -r '.providers | keys[]' '$config_file'" 2>/dev/null)
    else
        providers=$(bash -c "jq -r '.providers | keys[]' '$config_file'" 2>/dev/null)
    fi
    
    if [[ "$providers" =~ "openai" ]] && [[ "$providers" =~ "anthropic" ]]; then
        return 0
    else
        echo "Provider extraction test failed: $providers"
        return 1
    fi
}

# Test settings extraction
test_settings_extraction() {
    local shell="$1"
    setup_test_config
    
    local config_file="$CONFIG_DIR/config.json"
    local max_history
    
    if [[ "$shell" == "zsh" ]]; then
        max_history=$(zsh -c "jq -r '.settings.max_history_lines' '$config_file'" 2>/dev/null)
    else
        max_history=$(bash -c "jq -r '.settings.max_history_lines' '$config_file'" 2>/dev/null)
    fi
    
    if [[ "$max_history" == "50" ]]; then
        return 0
    else
        echo "Settings extraction test failed: max_history=$max_history"
        return 1
    fi
}

# Test config file creation
test_config_creation() {
    local shell="$1"
    
    # Remove existing config
    rm -f "$CONFIG_DIR/config.json"
    
    # Create new config from template
    local template_file="$CONFIG_DIR/ai-config.json"
    local config_file="$CONFIG_DIR/config.json"
    
    if [[ -f "$template_file" ]]; then
        cp "$template_file" "$config_file"
        
        # Test if new config is valid
        local validation_result
        if [[ "$shell" == "zsh" ]]; then
            validation_result=$(zsh -c "jq empty '$config_file'" 2>&1)
        else
            validation_result=$(bash -c "jq empty '$config_file'" 2>&1)
        fi
        
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "Config creation test failed: $validation_result"
            return 1
        fi
    else
        echo "Config creation test failed: template not found"
        return 1
    fi
} 