#!/bin/bash

set -eu

CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww}"
EWW=(eww -c "$CONFIG_DIR")
STATE_FILE="/tmp/eww-todo-current"
DEFAULT_FILE="$HOME/Documents/todo/1-todo.md"

if [[ -f "$STATE_FILE" ]]; then
    CURRENT_FILE="$(cat "$STATE_FILE")"
else
    CURRENT_FILE="$DEFAULT_FILE"
fi

CONTENT="$($CONFIG_DIR/scripts/todo-content.sh)"

"${EWW[@]}" update     "todo_current_file=$CURRENT_FILE"     "todo_content=$CONTENT"

if [[ "${1:-}" == "--reopen" ]] && "${EWW[@]}" active-windows 2>/dev/null | grep -Fq ': todo-overlay'; then
    "${EWW[@]}" close todo-overlay >/dev/null 2>&1 || true
    sleep 0.05
    "${EWW[@]}" open todo-overlay >/dev/null 2>&1 || true
fi
