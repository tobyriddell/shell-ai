#!/bin/bash
# Install tmux configuration, handling existing shell-ai configuration

set -e

TMUX_CONF="$HOME/.tmux.conf"
TMUX_CONF_BACKUP="$HOME/.tmux.conf.backup"

# Determine repository root: script is in scripts/, so go up one level
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMUX_CONF_SOURCE="$REPO_ROOT/config/tmux.conf"

# Check if source file exists
if [ ! -f "$TMUX_CONF_SOURCE" ]; then
    echo "Error: Source tmux.conf not found at $TMUX_CONF_SOURCE"
    exit 1
fi

# Extract shell-ai configuration from source (from "# AI Integration" to end of file)
SHELL_AI_SECTION=$(sed -n '/^# AI Integration keybindings/,$p' "$TMUX_CONF_SOURCE")

# Check if tmux.conf exists
if [ -f "$TMUX_CONF" ]; then
    # Check if it contains shell-ai configuration
    if grep -q "^# AI Integration keybindings" "$TMUX_CONF" 2>/dev/null; then
        echo "⚠️  Found existing shell-ai configuration in ~/.tmux.conf"
        
        # Make backup
        if [ ! -f "$TMUX_CONF_BACKUP" ]; then
            echo "📋 Creating backup: ~/.tmux.conf.backup"
            cp "$TMUX_CONF" "$TMUX_CONF_BACKUP"
        else
            # Create timestamped backup
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            TMUX_CONF_BACKUP_TIMESTAMP="$HOME/.tmux.conf.backup.$TIMESTAMP"
            echo "📋 Creating timestamped backup: ~/.tmux.conf.backup.$TIMESTAMP"
            cp "$TMUX_CONF" "$TMUX_CONF_BACKUP_TIMESTAMP"
        fi
        
        # Find the line number where shell-ai section starts
        AI_START_LINE=$(grep -n "^# AI Integration keybindings" "$TMUX_CONF" | head -1 | cut -d: -f1)
        
        if [ -n "$AI_START_LINE" ] && [ "$AI_START_LINE" -gt 0 ]; then
            # Create temporary file
            TEMP_FILE=$(mktemp)
            
            # Keep everything before the shell-ai section (up to line before AI_START_LINE)
            if [ "$AI_START_LINE" -gt 1 ]; then
                head -n $((AI_START_LINE - 1)) "$TMUX_CONF" > "$TEMP_FILE"
            else
                # If shell-ai section is at the very beginning, start with empty file
                > "$TEMP_FILE"
            fi
            
            # Ensure there's a newline before the shell-ai section if file is not empty
            if [ -s "$TEMP_FILE" ]; then
                # Check if last character is a newline
                if [ "$(tail -c 1 "$TEMP_FILE" | wc -l)" -eq 0 ]; then
                    echo "" >> "$TEMP_FILE"
                elif [ "$(tail -c 2 "$TEMP_FILE" | head -c 1)" != "" ]; then
                    # Last line doesn't end with newline, add one
                    echo "" >> "$TEMP_FILE"
                fi
            fi
            
            # Append new shell-ai section
            echo "$SHELL_AI_SECTION" >> "$TEMP_FILE"
            
            # Replace original file
            mv "$TEMP_FILE" "$TMUX_CONF"
            echo "✓ Replaced shell-ai configuration in ~/.tmux.conf"
        else
            # Fallback: append if we can't find the exact start
            echo "⚠️  Could not find exact shell-ai section start, appending new configuration"
            if [ ! -f "$TMUX_CONF_BACKUP" ]; then
                cp "$TMUX_CONF" "$TMUX_CONF_BACKUP"
            fi
            echo "" >> "$TMUX_CONF"
            echo "$SHELL_AI_SECTION" >> "$TMUX_CONF"
            echo "✓ Appended shell-ai configuration to ~/.tmux.conf"
        fi
    else
        # No shell-ai config found, just append
        echo "📝 Appending shell-ai configuration to existing ~/.tmux.conf"
        if [ ! -f "$TMUX_CONF_BACKUP" ]; then
            echo "📋 Creating backup: ~/.tmux.conf.backup"
            cp "$TMUX_CONF" "$TMUX_CONF_BACKUP"
        fi
        echo "" >> "$TMUX_CONF"
        echo "$SHELL_AI_SECTION" >> "$TMUX_CONF"
        echo "✓ Added shell-ai configuration to ~/.tmux.conf"
    fi
else
    # No existing file, just copy the entire source
    echo "📝 Creating new ~/.tmux.conf"
    cp "$TMUX_CONF_SOURCE" "$TMUX_CONF"
    echo "✓ Installed tmux configuration to ~/.tmux.conf"
fi
