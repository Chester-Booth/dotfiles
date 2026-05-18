#!/usr/bin/env bash
set -u

delta="${1:-1}"
TODO_DIR="$HOME/Documents/todo"
STATE_FILE="/tmp/waybar-todo-state"

mkdir -p "$TODO_DIR"
mapfile -t files < <(find "$TODO_DIR" -maxdepth 1 -type f -name "*.md" | sort)
count="${#files[@]}"

if [ "$count" -eq 0 ]; then
    touch "$TODO_DIR/todo.md"
    count=1
fi

current=0
if [ -f "$STATE_FILE" ]; then
    current="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
fi

[[ "$current" =~ ^-?[0-9]+$ ]] || current=0
[[ "$delta" =~ ^-?[0-9]+$ ]] || delta=1

next=$(( (current + delta) % count ))
if [ "$next" -lt 0 ]; then
    next=$((next + count))
fi

echo "$next" > "$STATE_FILE"
