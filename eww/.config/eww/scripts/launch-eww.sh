#!/bin/bash

set -eu

CONFIG_DIR="${EWW_CONFIG_DIR:-$HOME/.config/eww}"
MONITOR_SCRIPT="$CONFIG_DIR/scripts/workspace_monitor.sh"
EWW=(eww -c "$CONFIG_DIR")

pkill -f "$MONITOR_SCRIPT" >/dev/null 2>&1 || true
"${EWW[@]}" kill >/dev/null 2>&1 || true
pkill -x eww >/dev/null 2>&1 || true

"${EWW[@]}" daemon >/dev/null 2>&1 &

for _ in $(seq 1 50); do
    if "${EWW[@]}" ping >/dev/null 2>&1; then
        "$CONFIG_DIR/scripts/refresh-todo.sh" >/dev/null 2>&1 || true
        "$CONFIG_DIR/scripts/refresh-gcal.sh" >/dev/null 2>&1 || true
        "$MONITOR_SCRIPT" >/dev/null 2>&1 &
        exit 0
    fi

    sleep 0.1
done

echo "eww daemon did not become ready" >&2
exit 1
