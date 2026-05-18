#!/bin/bash

# --- config ---
STATE_FILE="/tmp/eww-gcal-current"
TODO_DIR="$HOME/Documents/todo"

# get current file
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    # fallback
    CURRENT="$TODO_DIR/2-gcal.md"
fi

# read content
if [ -f "$CURRENT" ]; then
    CONTENT=$(cat "$CURRENT")
else
    CONTENT="File not found"
fi


printf "%s\n" "$CONTENT"
