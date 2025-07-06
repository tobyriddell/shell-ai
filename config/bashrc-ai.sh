# AI Integration Functions
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

# Enhanced command_not_found_handle for AI prefix
command_not_found_handle() {
    local cmd="$1"
    
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
    echo "bash: $cmd: command not found"
    return 127
}

# Function to quickly ask AI about the last command
ai-last() {
    local last_cmd
    if command -v atuin >/dev/null 2>&1; then
        last_cmd=$(atuin history list --limit 1 | head -n1)
    else
        last_cmd=$(history | tail -n1 | sed 's/^[ ]*[0-9]*[ ]*//')
    fi
    
    if [[ -n "$last_cmd" ]]; then
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
        last_cmd=$(atuin history list --limit 1 | head -n1)
    else
        last_cmd=$(history | tail -n1 | sed 's/^[ ]*[0-9]*[ ]*//')
    fi
    
    if [[ -n "$last_cmd" ]]; then
        $HOME/.config/shell-ai/ai-shell.sh "The command '$last_cmd' failed. Please suggest how to fix it or provide the correct command."
    else
        echo "No recent command found"
    fi
}

alias ai-last='ai-last'
alias ai-here='ai-here'
alias ai-fix='ai-fix' 