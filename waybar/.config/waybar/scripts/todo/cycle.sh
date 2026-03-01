#!/bin/bash

TODO_DIR="$HOME/Documents/todo"
STATE_FILE="/tmp/waybar-todo-state"

# Get all markdown files in the todo directory
mapfile -t files < <(find "$TODO_DIR" -maxdepth 1 -type f -name "*.md" | sort)

# Read current index from state file, default to 0
if [ -f "$STATE_FILE" ]; then
    current_index=$(cat "$STATE_FILE")
else
    current_index=0
fi

# Increment index and wrap around
current_index=$(( (current_index + 1) % ${#files[@]} ))

# Save new index
echo "$current_index" > "$STATE_FILE"

# Force waybar to update by sending a signal or just exit
# Waybar will refresh on its interval