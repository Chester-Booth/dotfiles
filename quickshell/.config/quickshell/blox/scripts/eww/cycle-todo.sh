#!/bin/bash

STATE_FILE="/tmp/eww-todo-current"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Get all todo files except gcal/today/week widgets
FILES=($(ls ~/Documents/todo/*.md 2>/dev/null | grep -Ev '/(2-gcal|80-today|81-week|99-gcal_week)\.md$' | sort))

if [ ${#FILES[@]} -eq 0 ]; then
    echo "~/Documents/todo/1-todo.md"
    exit
fi

# Get current file
if [ -f "$STATE_FILE" ]; then
    CURRENT=$(cat "$STATE_FILE")
else
    CURRENT="${FILES[0]}"
fi

# Find current index
CURRENT_INDEX=-1
for i in "${!FILES[@]}"; do
    if [ "${FILES[$i]}" = "$CURRENT" ]; then
        CURRENT_INDEX=$i
        break
    fi
done

# Cycle to next file
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#FILES[@]} ))
NEXT_FILE="${FILES[$NEXT_INDEX]}"

# Save state
echo "$NEXT_FILE" > "$STATE_FILE"

"$SCRIPT_DIR/refresh-todo.sh" --reopen
