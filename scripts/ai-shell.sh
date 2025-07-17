#!/bin/bash

CONFIG_DIR="$HOME/.config/shell-ai"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONTEXT_FILE="$CONFIG_DIR/context.tmp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default settings
MAX_HISTORY_LINES=50
MAX_PANE_LINES=100

# Get script directory for loading providers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="$SCRIPT_DIR/providers"

show_help() {
    echo -e "${BLUE}Shell AI Integration${NC}"
    echo
    echo "Usage: $0 [OPTIONS] [PROMPT]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help"
    echo "  -t, --test          Test AI provider connection"
    echo "  -c, --context       Show context that would be sent to AI"
    echo "  -p, --provider      Specify AI provider (openai, anthropic, google, ollama)"
    echo "  --history-lines N   Number of history lines to include (default: $MAX_HISTORY_LINES)"
    echo "  --pane-lines N      Number of pane lines to include (default: $MAX_PANE_LINES)"
    echo "  --no-history        Don't include shell history"
    echo "  --no-pane           Don't include tmux pane content"
    echo
    echo "Examples:"
    echo "  $0 'Explain the last command I ran'"
    echo "  $0 --provider openai 'Help me fix this error'"
    echo "  $0 --context  # Show what context would be sent"
}

get_shell_history() {
    if command -v atuin >/dev/null 2>&1; then
        # Check if invoked from tmux - if so, use global history instead of session-specific
        if [[ -n "$AI_SHELL_TMUX_INVOKED" ]]; then
            # Use global history when invoked from tmux (drop -s flag)
            atuin history list -f '{command}' | tail -n "$MAX_HISTORY_LINES" 2>/dev/null || echo "No atuin history available"
        else
            # Use session-specific history for normal invocations
            atuin history list -s -f '{command}' | tail -n "$MAX_HISTORY_LINES" 2>/dev/null || echo "No atuin history available"
        fi
    else
        # Detect shell type and use appropriate history command
        if [[ -n "$ZSH_VERSION" ]]; then
            # Zsh history using fc command
            fc -l -"$MAX_HISTORY_LINES" 2>/dev/null | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo "No zsh history available"
        elif [[ -n "$BASH_VERSION" ]]; then
            # Bash history from history file
            tail -n "$MAX_HISTORY_LINES" ~/.bash_history 2>/dev/null || echo "No bash history available"
        else
            # Generic fallback
            tail -n "$MAX_HISTORY_LINES" ~/.sh_history 2>/dev/null || echo "No shell history available"
        fi
    fi
}

get_tmux_pane_content() {
    local target_pane="${1:-$TMUX_PANE}"
    if [[ -n "$TMUX" ]]; then
        # tmux capture-pane -t "$target_pane" -p -S "-$MAX_PANE_LINES" 2>/dev/null || echo "No tmux pane content available"
        tmux capture-pane -t "$target_pane" -p 2>/dev/null || echo "No tmux pane content available"
    else
        echo "Not running in tmux"
    fi
}

build_context() {
    local include_history="$1"
    local include_pane="$2"
    local target_pane="$3"
    
    # Gather all data first before any output
    local shell_history=""
    local pane_content=""
    
    if [[ "$include_history" == "true" ]]; then
        shell_history=$(get_shell_history)
    fi
    
    if [[ "$include_pane" == "true" ]]; then
        pane_content=$(get_tmux_pane_content "$target_pane")
    fi
    
    # Now output everything
    echo "=== SYSTEM CONTEXT ==="
    echo "OS: $(uname -a)"
    echo "Shell: $SHELL"
    echo "Working Directory: $(pwd)"
    echo
    
    if [[ "$include_history" == "true" ]]; then
        echo "=== RECENT SHELL HISTORY ==="
        echo "$shell_history"
        echo "=== END OF SHELL HISTORY ==="
    fi
    
    if [[ "$include_pane" == "true" ]]; then
        echo "=== CURRENT TMUX PANE CONTENT ==="
        echo "$pane_content"
        echo "=== END OF TMUX PANE CONTENT ==="
    fi
}

get_active_provider() {
    local specified_provider="$1"
    
    if [[ -n "$specified_provider" ]]; then
        echo "$specified_provider"
        return
    fi
    
    # Find first enabled provider
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r '.providers | to_entries[] | select(.value.enabled == true) | .key' "$CONFIG_FILE" | head -n1
    fi
}

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

call_ai_provider() {
    local provider="$1"
    local prompt="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Error: No configuration found. Run ai-setup first.${NC}"
        return 1
    fi
    
    local provider_config
    provider_config=$(jq -r ".providers.$provider // empty" "$CONFIG_FILE")
    
    if [[ -z "$provider_config" ]]; then
        echo -e "${RED}Error: Provider '$provider' not configured.${NC}"
        return 1
    fi
    
    local enabled
    enabled=$(echo "$provider_config" | jq -r '.enabled // false')
    if [[ "$enabled" != "true" ]]; then
        echo -e "${RED}Error: Provider '$provider' is not enabled.${NC}"
        return 1
    fi
    
    # Check if provider function exists
    if ! declare -f "call_$provider" >/dev/null 2>&1; then
        echo -e "${RED}Error: Provider '$provider' not loaded or function not found${NC}"
        return 1
    fi
    
    # Call the provider function with standardized parameters
    # Pass the entire provider config and let each provider extract what it needs
    "call_$provider" "$provider_config" "$prompt"
}

# Parse command line arguments
PROVIDER=""
PROMPT=""
INCLUDE_HISTORY="true"
INCLUDE_PANE="true"
SHOW_CONTEXT="false"
TEST_MODE="false"
TARGET_PANE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            TEST_MODE="true"
            shift
            ;;
        -c|--context)
            SHOW_CONTEXT="true"
            shift
            ;;
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        --history-lines)
            MAX_HISTORY_LINES="$2"
            shift 2
            ;;
        --pane-lines)
            MAX_PANE_LINES="$2"
            shift 2
            ;;
        --no-history)
            INCLUDE_HISTORY="false"
            shift
            ;;
        --no-pane)
            INCLUDE_PANE="false"
            shift
            ;;
        --pane)
            TARGET_PANE="$2"
            shift 2
            ;;
        *)
            PROMPT="$PROMPT $1"
            shift
            ;;
    esac
done

# Trim leading/trailing whitespace from prompt
PROMPT=$(echo "$PROMPT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Build context
CONTEXT=$(build_context "$INCLUDE_HISTORY" "$INCLUDE_PANE" "$TARGET_PANE")

if [[ "$SHOW_CONTEXT" == "true" ]]; then
    echo -e "${YELLOW}Context that would be sent to AI:${NC}"
    echo "$CONTEXT"
    exit 0
fi

if [[ "$TEST_MODE" == "true" ]]; then
    echo -e "${YELLOW}Testing AI providers...${NC}"
    echo
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}No configuration found. Run ai-setup first.${NC}"
        exit 1
    fi
    
    # Test each enabled provider
    while IFS= read -r provider; do
        echo -e "${CYAN}Testing $provider...${NC}"
        response=$(call_ai_provider "$provider" "Hello, respond with just 'OK' to confirm you're working.")
        if [[ "$response" == *"OK"* ]] || [[ "$response" == *"ok"* ]]; then
            echo -e "${GREEN}✓ $provider is working${NC}"
        else
            echo -e "${RED}✗ $provider failed: $response${NC}"
        fi
        echo
    done < <(jq -r '.providers | to_entries[] | select(.value.enabled == true) | .key' "$CONFIG_FILE")
    
    exit 0
fi

if [[ -z "$PROMPT" ]]; then
    echo -e "${RED}Error: No prompt provided${NC}"
    show_help
    exit 1
fi

# Get active provider
ACTIVE_PROVIDER=$(get_active_provider "$PROVIDER")

if [[ -z "$ACTIVE_PROVIDER" ]]; then
    echo -e "${RED}Error: No AI provider configured or enabled. Run ai-setup first.${NC}"
    exit 1
fi

# Build full prompt with context
FULL_PROMPT="$CONTEXT

=== USER PROMPT ===
$PROMPT

Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed."

echo -e "${BLUE}🤖 Asking $ACTIVE_PROVIDER...${NC}"
echo

# Call AI provider
RESPONSE=$(call_ai_provider "$ACTIVE_PROVIDER" "$FULL_PROMPT")

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Response:${NC}"
    echo "$RESPONSE"
    
    # Save response to temp file for potential tmux integration
    echo "$RESPONSE" > "$CONFIG_DIR/last_response.txt"
    
    # Check auto-copy settings
    auto_copy="false"
    auto_copy_prompt="true"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Read boolean values and ensure they're converted to strings properly
        auto_copy=$(jq -r '.settings.auto_copy' "$CONFIG_FILE" 2>/dev/null || echo "false")
        auto_copy_prompt=$(jq -r '.settings.auto_copy_prompt' "$CONFIG_FILE" 2>/dev/null || echo "true")
    fi
    
    # If in tmux, handle auto-copy or show tips
    if [[ -n "$TMUX" ]]; then
        echo
        echo -e "${YELLOW}Tip: Response saved to $CONFIG_DIR/last_response.txt${NC}"
        
        if [[ "$auto_copy" == "true" ]]; then
            if [[ "$auto_copy_prompt" != "false" ]]; then
                echo -e "${CYAN}Launch ai-copy to manage response? (y/N):${NC}"
                read -n 1 -r reply
                echo
                if [[ $reply =~ ^[Yy]$ ]]; then
                    exec "$CONFIG_DIR/ai-copy.sh"
                fi
            else
                echo -e "${YELLOW}Auto-launching ai-copy...${NC}"
                exec "$CONFIG_DIR/ai-copy.sh"
            fi
        else
            echo -e "${YELLOW}Use 'ai-copy' to copy commands to your shell${NC}"
        fi
    fi
else
    echo -e "${RED}Error: Failed to get response from AI provider${NC}"
    exit 1
fi 