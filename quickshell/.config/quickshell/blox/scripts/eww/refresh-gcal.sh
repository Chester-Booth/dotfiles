#!/bin/bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${EWW_CONFIG_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
EWW=(eww -c "$CONFIG_DIR")
STATE_FILE="/tmp/eww-gcal-current"
DEFAULT_FILE="$HOME/Documents/todo/2-gcal.md"
TODO_DIR="$HOME/Documents/todo"
EXPENSES_API_BASE_URL="${EXPENSES_API_BASE_URL:-}"

sync_expenses_todo_files() {
    [[ -n "$EXPENSES_API_BASE_URL" ]] || return 0

    mkdir -p "$TODO_DIR"

    local today_tmp week_tmp
    today_tmp="$(mktemp)"
    week_tmp="$(mktemp)"

    curl -fsS --connect-timeout 2 --max-time 8 \
        -X POST "$EXPENSES_API_BASE_URL/api/exports/regenerate" >/dev/null || true

    if curl -fsS --connect-timeout 2 --max-time 6 \
        "$EXPENSES_API_BASE_URL/api/chart/today-text" > "$today_tmp"; then
        mv "$today_tmp" "$TODO_DIR/80-today.md"
    else
        rm -f "$today_tmp"
    fi

    if curl -fsS --connect-timeout 2 --max-time 6 \
        "$EXPENSES_API_BASE_URL/api/chart/week-text" > "$week_tmp"; then
        mv "$week_tmp" "$TODO_DIR/81-week.md"
    else
        rm -f "$week_tmp"
    fi
}

if [[ -f "$STATE_FILE" ]]; then
    CURRENT_FILE="$(cat "$STATE_FILE")"
else
    CURRENT_FILE="$DEFAULT_FILE"
fi

sync_expenses_todo_files

CONTENT="$($CONFIG_DIR/scripts/gcal-content.sh)"

"${EWW[@]}" update     "gcal_current_file=$CURRENT_FILE"     "gcal_content=$CONTENT"

if [[ "${1:-}" == "--reopen" ]] && "${EWW[@]}" active-windows 2>/dev/null | grep -Fq ': gcal-overlay'; then
    "${EWW[@]}" close gcal-overlay >/dev/null 2>&1 || true
    sleep 0.05
    "${EWW[@]}" open gcal-overlay >/dev/null 2>&1 || true
fi
