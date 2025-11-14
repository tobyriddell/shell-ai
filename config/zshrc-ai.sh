# Shell AI Integration (Go Implementation) for Zsh
# Ensure shell-ai is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Create aliases for AI commands (Go implementation)
alias ai='shell-ai ask'
alias ai-interactive='shell-ai interactive'
alias ai-setup='shell-ai setup'
alias ai-test='shell-ai test'
alias ai-go='shell-ai'

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
            shell-ai ask "$ai_prompt"
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
        shell-ai ask "Explain this command: $last_cmd"
    else
        echo "No recent command found"
    fi
}

# Function to ask AI about current directory
ai-here() {
    local current_dir=$(pwd)
    local file_list=$(ls -la 2>/dev/null | head -20)
    shell-ai ask "I'm in directory $current_dir with these files: $file_list. $*"
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
        shell-ai ask "The command '$last_cmd' failed. Please suggest how to fix it or provide the correct command."
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