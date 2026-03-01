#!/bin/bash

TODO_DIR="$HOME/Documents/todo"
STATE_FILE="/tmp/waybar-todo-state"

# Create todo directory if it doesn't exist
mkdir -p "$TODO_DIR"

# Get all markdown files in the todo directory
mapfile -t files < <(find "$TODO_DIR" -maxdepth 1 -type f -name "*.md" | sort)

# If no files exist, create default todo.md
if [ ${#files[@]} -eq 0 ]; then
    touch "$TODO_DIR/todo.md"
    files=("$TODO_DIR/todo.md")
fi

# Read current index from state file, default to 0
if [ -f "$STATE_FILE" ]; then
    current_index=$(cat "$STATE_FILE")
else
    current_index=0
fi

# Ensure index is valid
if [ "$current_index" -ge ${#files[@]} ] || [ "$current_index" -lt 0 ]; then
    current_index=0
fi

# Get the current file
current_file="${files[$current_index]}"

# Read the file content
if [ -f "$current_file" ]; then
    content=$(cat "$current_file")
else
    content="File not found"
fi

# Get just the filename for the header
filename=$(basename "$current_file")

# Create tooltip with header and content
tooltip="# $filename $((current_index + 1))/$(( ${#files[@]} ))

$content"

# Export current file path for use by click handlers
echo "$current_file" > /tmp/waybar-todo-current-file

# Use jq to safely package it into JSON
jq -nc --arg todo "$tooltip" '{"text": "󰺦", "tooltip": $todo}'