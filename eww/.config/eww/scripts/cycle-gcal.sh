#!/bin/bash

STATE_FILE="/tmp/eww-gcal-current"

FILES=(
    ~/Documents/todo/2-gcal.md
    ~/Documents/todo/80-today.md
    ~/Documents/todo/81-week.md
    ~/Documents/todo/99-gcal_week.md
)

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
NEXT="${FILES[$NEXT_INDEX]}"

# Save state
echo "$NEXT" > "$STATE_FILE"

"$HOME/.config/eww/scripts/refresh-gcal.sh" --reopen
