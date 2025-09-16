#!/bin/bash

# Script to create 10 tmux windows each with 5 panes
# Usage: ./create_tmux_layout.sh [session_name]

SESSION_NAME=${1:-"multi-pane-session"}

echo "Creating tmux session '$SESSION_NAME' with 10 windows, each having 5 panes..."

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed. Please install tmux first."
    exit 1
fi

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists. Attaching to existing session..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create new tmux session (detached)
tmux new-session -d -s "$SESSION_NAME" -x 120 -y 40

# Rename the first window
tmux rename-window -t "$SESSION_NAME:0" "Window-1"

# Create 5 panes in the first window
# Start with 1 pane, split to create 4 more
tmux split-window -h -t "$SESSION_NAME:0"           # Split horizontally (2 panes)
tmux split-window -v -t "$SESSION_NAME:0.0"         # Split first pane vertically
tmux split-window -v -t "$SESSION_NAME:0.2"         # Split second main pane vertically
tmux split-window -h -t "$SESSION_NAME:0.3"         # Split bottom pane horizontally

# Create 9 more windows (windows 1-9) each with 5 panes
for i in {1..9}; do
    # Create new window
    tmux new-window -t "$SESSION_NAME" -n "Window-$((i+1))"
    
    # Create 5 panes in this window (same layout as first window)
    tmux split-window -h -t "$SESSION_NAME:$i"           # Split horizontally (2 panes)
    tmux split-window -v -t "$SESSION_NAME:$i.0"         # Split first pane vertically
    tmux split-window -v -t "$SESSION_NAME:$i.2"         # Split second main pane vertically  
    tmux split-window -h -t "$SESSION_NAME:$i.3"         # Split bottom pane horizontally
    
    # Optional: Set a tiled layout for better organization
    tmux select-layout -t "$SESSION_NAME:$i" tiled
done

# Set tiled layout for the first window as well
tmux select-layout -t "$SESSION_NAME:0" tiled

# Go back to the first window
tmux select-window -t "$SESSION_NAME:0"

# Select the first pane
tmux select-pane -t "$SESSION_NAME:0.0"

echo "Created tmux session '$SESSION_NAME' with 10 windows, each having 5 panes."
echo "To attach to the session, run: tmux attach-session -t $SESSION_NAME"
echo "To list all sessions, run: tmux list-sessions"
echo "To kill the session, run: tmux kill-session -t $SESSION_NAME"

# Optionally attach to the session immediately
read -p "Do you want to attach to the session now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    tmux attach-session -t "$SESSION_NAME"
fi 