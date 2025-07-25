# AI Integration Functions for Zsh
export PATH="$HOME/.config/shell-ai:$PATH"

# AI command prefix handler
ai_prefix_handler() {
    local cmd="$1"
    shift
    local prompt="$*"
    
    case "$cmd" in
        "ai"|"AI")
            $HOME/.config/shell-ai/ai-shell.sh "$prompt"
            ;;
        "ai-setup")
            $HOME/.config/shell-ai/ai-setup.sh
            ;;
        "ai-copy")
            $HOME/.config/shell-ai/ai-copy.sh
            ;;
        "ai-context")
            $HOME/.config/shell-ai/ai-shell.sh --context
            ;;
        "ai-test")
            $HOME/.config/shell-ai/ai-shell.sh --test
            ;;
        "ai-pane")
            $HOME/.config/shell-ai/tmux-ai-pane.sh
            ;;
        *)
            echo "Unknown AI command: $cmd"
            echo "Available commands: ai, ai-setup, ai-copy, ai-context, ai-test, ai-pane"
            return 1
            ;;
    esac
}

# Create aliases for AI commands
alias ai='$HOME/.config/shell-ai/ai-shell.sh'
alias ai-setup='$HOME/.config/shell-ai/ai-setup.sh'
alias ai-copy='$HOME/.config/shell-ai/ai-copy.sh'
alias ai-context='$HOME/.config/shell-ai/ai-shell.sh --context'
alias ai-test='$HOME/.config/shell-ai/ai-shell.sh --test'
alias ai-pane='$HOME/.config/shell-ai/tmux-ai-pane.sh'

# Enhanced command_not_found_handler for AI prefix (note: zsh uses command_not_found_handler)
command_not_found_handler() {
    local cmd="$1"

    echo "command_not_found_handler called with cmd: $cmd" > /tmp/log2
    
    # Check if command starts with @ (AI prefix)
    if [[ "$cmd" == @* ]]; then
        local ai_prompt="${cmd#@}"  # Remove @ prefix
        shift  # Remove first argument
        if [[ -n "$*" ]]; then
            ai_prompt="$ai_prompt $*"  # Combine with remaining arguments
        fi
        
        if [[ -n "$ai_prompt" ]]; then
            echo "🤖 AI Query: $ai_prompt"
            $HOME/.config/shell-ai/ai-shell.sh "$ai_prompt"
        else
            echo "Usage: @<prompt> - Ask AI a question"
            echo "Example: @how do I list files recursively"
        fi
        return 0
    fi
    
    # Default behavior for other commands
    echo "zsh: command not found: $cmd"
    return 127
}

# Function to quickly ask AI about the last command you ran
ai-last() {
    local last_cmd
    if command -v atuin >/dev/null 2>&1; then
        last_cmd=$(atuin history list | head -n1)
    else
        # Zsh uses fc for history
        last_cmd=$(fc -ln -1)
    fi
    
    if [[ -n "$last_cmd" ]]; then
        # Trim leading whitespace from zsh history
        last_cmd=$(echo "$last_cmd" | sed 's/^[[:space:]]*//')
        $HOME/.config/shell-ai/ai-shell.sh "Explain this command: $last_cmd"
    else
        echo "No recent command found"
    fi
}

# Function to ask AI about current directory
ai-here() {
    local current_dir=$(pwd)
    local file_list=$(ls -la 2>/dev/null | head -20)
    $HOME/.config/shell-ai/ai-shell.sh "I'm in directory $current_dir with these files: $file_list. $*"
}

# Function to ask AI to fix the last command
ai-fix() {
    local last_cmd
    if command -v atuin >/dev/null 2>&1; then
        last_cmd=$(atuin history list | head -n1)
    else
        # Zsh uses fc for history
        last_cmd=$(fc -ln -1)
    fi
    
    if [[ -n "$last_cmd" ]]; then
        # Trim leading whitespace from zsh history
        last_cmd=$(echo "$last_cmd" | sed 's/^[[:space:]]*//')
        $HOME/.config/shell-ai/ai-shell.sh "The command '$last_cmd' failed. Please suggest how to fix it or provide the correct command."
    else
        echo "No recent command found"
    fi
}

# Enable zsh autoloading for better function handling
autoload -Uz compinit
compinit

# Set up zsh options for better history handling
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY

alias ai-last='ai-last'
alias ai-here='ai-here'
alias ai-fix='ai-fix' 