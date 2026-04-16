#!/bin/bash

set -eu

STATE_FILE="/tmp/eww-todo-current"
DEFAULT_FILE="$HOME/Documents/todo/1-todo.md"
TODO_RENDER_SCRIPT="$HOME/.config/eww/scripts/todo-content.sh"
TARGET_X=60
TARGET_Y=20
CHAR_WIDTH=9
LINE_HEIGHT=22
PADDING_X=40
PADDING_Y=40
MIN_W=200
MIN_H=80

if [[ -f "$STATE_FILE" ]]; then
    CURRENT_FILE="$(cat "$STATE_FILE")"
else
    CURRENT_FILE="$DEFAULT_FILE"
fi

CONTENT="$($TODO_RENDER_SCRIPT)"

LINE_COUNT="$(printf '%s
' "$CONTENT" | awk 'END { print NR + 0 }')"
MAX_CHARS="$(printf '%s
' "$CONTENT" | awk '{ if (length > max) max = length } END { print max + 0 }')"

TARGET_W=$((MAX_CHARS * CHAR_WIDTH + PADDING_X))
TARGET_H=$((LINE_COUNT * LINE_HEIGHT + PADDING_Y))

if (( TARGET_W < MIN_W )); then
    TARGET_W=$MIN_W
fi

if (( TARGET_H < MIN_H )); then
    TARGET_H=$MIN_H
fi

read_window_address() {
    local pid="$1"

    hyprctl -j clients 2>/dev/null | jq -r --argjson pid "$pid" '
        [.[] | select(.pid == $pid and .class == "eww_todo") | .address]
        | first // empty
    ' 2>/dev/null
}

kitty --class eww_todo --title eww_todo micro "$CURRENT_FILE" >/dev/null 2>&1 &
KITTY_PID=$!
WINDOW_ADDRESS=""

for _ in $(seq 1 50); do
    WINDOW_ADDRESS="$(read_window_address "$KITTY_PID")"
    if [[ -n "$WINDOW_ADDRESS" ]]; then
        break
    fi

    sleep 0.1
done

if [[ -z "$WINDOW_ADDRESS" ]]; then
    exit 0
fi

sleep 0.15
hyprctl --batch "dispatch focuswindow address:$WINDOW_ADDRESS; dispatch resizeactive exact $TARGET_W $TARGET_H; dispatch moveactive exact $TARGET_X $TARGET_Y" >/dev/null 2>&1 || true
sleep 0.05
hyprctl --batch "dispatch focuswindow address:$WINDOW_ADDRESS; dispatch resizeactive exact $TARGET_W $TARGET_H; dispatch moveactive exact $TARGET_X $TARGET_Y" >/dev/null 2>&1 || true
