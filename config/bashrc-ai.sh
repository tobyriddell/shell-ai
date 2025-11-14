# Shell AI Integration (Go Implementation)
# Ensure shell-ai is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Initialize atuin if available
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash)"
fi

# Create aliases for AI commands (Go implementation)
alias ai='shell-ai ask'
alias ai-interactive='shell-ai interactive'
alias ai-setup='shell-ai setup'
alias ai-test='shell-ai test'
alias ai-go='shell-ai'

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
            shell-ai ask "$ai_prompt"
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

# Function to quickly ask AI about the last command you ran
ai-last() {
    local last_cmd
    if command -v atuin >/dev/null 2>&1; then
        last_cmd=$(atuin history list | head -n1)
    else
        last_cmd=$(history | tail -n1 | sed 's/^[ ]*[0-9]*[ ]*//')
    fi
    
    if [[ -n "$last_cmd" ]]; then
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
        last_cmd=$(history | tail -n1 | sed 's/^[ ]*[0-9]*[ ]*//')
    fi
    
    if [[ -n "$last_cmd" ]]; then
        shell-ai ask "The command '$last_cmd' failed. Please suggest how to fix it or provide the correct command."
    else
        echo "No recent command found"
    fi
}

alias ai-last='ai-last'
alias ai-here='ai-here'
alias ai-fix='ai-fix' 
