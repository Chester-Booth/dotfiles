#!/usr/bin/env bash
set -u

STATE_FILE="/tmp/eww-todo-current"
DEFAULT_FILE="$HOME/Documents/todo/1-todo.md"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_X=60
TARGET_Y=20
CHAR_WIDTH=9
LINE_HEIGHT=22
PADDING_X=40
PADDING_Y=40
MIN_W=200
MIN_H=80

current_file="$DEFAULT_FILE"
if [ -f "$STATE_FILE" ]; then
    current_file="$(cat "$STATE_FILE" 2>/dev/null || printf '%s\n' "$DEFAULT_FILE")"
fi

content="$("$SCRIPT_DIR/todo-content.sh")"

line_count="$(printf '%s\n' "$content" | awk 'END { print NR + 0 }')"
max_chars="$(printf '%s\n' "$content" | awk '{ if (length > max) max = length } END { print max + 0 }')"

target_w=$((max_chars * CHAR_WIDTH + PADDING_X))
target_h=$((line_count * LINE_HEIGHT + PADDING_Y))

if [ "$target_w" -lt "$MIN_W" ]; then
    target_w="$MIN_W"
fi

if [ "$target_h" -lt "$MIN_H" ]; then
    target_h="$MIN_H"
fi

read_window_address() {
    local pid="$1"

    hyprctl -j clients 2>/dev/null | jq -r --argjson pid "$pid" '
        [.[] | select(.pid == $pid and .class == "quickshell_todo") | .address]
        | first // empty
    ' 2>/dev/null
}

kitty --class quickshell_todo --title quickshell_todo micro "$current_file" >/dev/null 2>&1 &
kitty_pid=$!
window_address=""

for _ in $(seq 1 50); do
    window_address="$(read_window_address "$kitty_pid")"
    if [ -n "$window_address" ]; then
        break
    fi

    sleep 0.1
done

if [ -z "$window_address" ]; then
    exit 0
fi

sleep 0.15
hyprctl --batch "dispatch focuswindow address:$window_address; dispatch resizeactive exact $target_w $target_h; dispatch moveactive exact $TARGET_X $TARGET_Y" >/dev/null 2>&1 || true
sleep 0.05
hyprctl --batch "dispatch focuswindow address:$window_address; dispatch resizeactive exact $target_w $target_h; dispatch moveactive exact $TARGET_X $TARGET_Y" >/dev/null 2>&1 || true
