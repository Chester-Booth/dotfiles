#!/usr/bin/env bash
set -u

STATE_FILE="/tmp/eww-gcal-current"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TODO_DIR="$HOME/Documents/todo"

files=(
    "$TODO_DIR/2-gcal.md"
    "$TODO_DIR/80-today.md"
    "$TODO_DIR/81-week.md"
    "$TODO_DIR/99-gcal_week.md"
)

current="${files[0]}"
if [ -f "$STATE_FILE" ]; then
    current="$(cat "$STATE_FILE" 2>/dev/null || printf '%s\n' "${files[0]}")"
fi

current_index=-1
for i in "${!files[@]}"; do
    if [ "${files[$i]}" = "$current" ]; then
        current_index="$i"
        break
    fi
done

next_index=$(( (current_index + 1) % ${#files[@]} ))
printf '%s\n' "${files[$next_index]}" > "$STATE_FILE"

"$SCRIPT_DIR/todo-generated-refresh.sh" >/dev/null 2>&1 || true
