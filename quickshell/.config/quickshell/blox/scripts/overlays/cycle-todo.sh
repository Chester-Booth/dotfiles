#!/usr/bin/env bash
set -u

STATE_FILE="/tmp/eww-todo-current"
TODO_DIR="$HOME/Documents/todo"

mkdir -p "$TODO_DIR"
mapfile -t files < <(find "$TODO_DIR" -maxdepth 1 -type f -name "*.md" | grep -Ev '/(2-gcal|80-today|81-week|99-gcal_week)\.md$' | sort)

if [ "${#files[@]}" -eq 0 ]; then
    printf '%s\n' "$TODO_DIR/1-todo.md"
    exit 0
fi

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
