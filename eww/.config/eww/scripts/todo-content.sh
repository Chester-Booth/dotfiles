#!/bin/bash

# --- config ---
STATE_FILE="/tmp/eww-todo-current"
TODO_DIR="$HOME/Documents/todo"

# get current file
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    CURRENT="$TODO_DIR/1-todo.md"
fi

# build file list excluding gcal/today/week widget files
FILES=($(ls "$TODO_DIR"/*.md 2>/dev/null | grep -Ev '/(2-gcal|80-today|81-week|99-gcal_week)\.md$' | sort))

# count files
COUNT=${#FILES[@]}

# compute current file position (1-based)
POS=1
for i in "${!FILES[@]}"; do
    if [ "${FILES[$i]}" = "$CURRENT" ]; then
        POS=$((i + 1))
        break
    fi
done

# header
FILENAME=$(basename "$CURRENT")
HEADER="# $FILENAME $POS/$COUNT"

# read content
if [ -f "$CURRENT" ]; then
    CONTENT=$(cat "$CURRENT")
else
    CONTENT="File not found"
fi

printf "%s
%s
" "$HEADER" "$CONTENT"
