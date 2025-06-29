#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$TMUX" ]]; then
    echo -e "${RED}Not running in tmux${NC}"
    exit 1
fi

# Create AI input pane
create_ai_pane() {
    local pane_title="AI-Input"
    
    # Split current pane horizontally (20% height for AI input)
    tmux split-window -v -p 20 -t "$TMUX_PANE"
    
    # Get the new pane ID
    local ai_pane
    ai_pane=$(tmux display-message -p '#{pane_id}')
    
    # Set pane title
    tmux select-pane -t "$ai_pane" -T "$pane_title"
    
    # Create AI input session in the new pane
    tmux send-keys -t "$ai_pane" "cd $HOME && clear" C-m
    tmux send-keys -t "$ai_pane" "echo -e '${BLUE}AI Input Pane - Type your prompts here${NC}'" C-m
    tmux send-keys -t "$ai_pane" "echo -e '${YELLOW}Commands:${NC}'" C-m
    tmux send-keys -t "$ai_pane" "echo '  ai <prompt>     - Send prompt to AI'" C-m
    tmux send-keys -t "$ai_pane" "echo '  ai-context     - Show context'" C-m
    tmux send-keys -t "$ai_pane" "echo '  ai-copy        - Manage AI responses'" C-m
    tmux send-keys -t "$ai_pane" "echo '  exit           - Close this pane'" C-m
    tmux send-keys -t "$ai_pane" "echo" C-m
    
    # Create aliases for the AI pane
    tmux send-keys -t "$ai_pane" "alias ai='~/.config/shell-ai/ai-shell.sh'" C-m
    tmux send-keys -t "$ai_pane" "alias ai-context='~/.config/shell-ai/ai-shell.sh --context'" C-m
    tmux send-keys -t "$ai_pane" "alias ai-copy='~/.config/shell-ai/ai-copy.sh'" C-m
    
    # Switch back to original pane
    tmux select-pane -t "$TMUX_PANE"
    
    echo -e "${GREEN}AI input pane created. Use Ctrl-A + arrow keys to navigate.${NC}"
}

# Toggle AI pane
toggle_ai_pane() {
    # Check if AI pane exists
    local ai_pane_count
    ai_pane_count=$(tmux list-panes -F '#{pane_title}' | grep -c "AI-Input" || true)
    
    if [[ "$ai_pane_count" -gt 0 ]]; then
        # Close AI panes
        tmux kill-pane -t "{AI-Input}" 2>/dev/null || true
        echo -e "${YELLOW}AI pane closed${NC}"
    else
        create_ai_pane
    fi
}

case "${1:-toggle}" in
    "create") create_ai_pane ;;
    "toggle") toggle_ai_pane ;;
    *) toggle_ai_pane ;;
esac 