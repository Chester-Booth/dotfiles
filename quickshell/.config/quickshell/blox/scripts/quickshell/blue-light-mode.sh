#!/usr/bin/env bash
set -u

mode="${1:-auto}"
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
state_file="$state_dir/blue-light-mode"

mkdir -p "$state_dir"

start_filter() {
    if ! pgrep -x hyprsunset >/dev/null; then
        hyprsunset >/dev/null 2>&1 &
    fi
}

stop_filter() {
    pkill -x hyprsunset >/dev/null 2>&1 || true
}

auto_active() {
    local hour
    hour="$(date +%H)"
    [[ "$hour" =~ ^[0-9]+$ ]] || hour=0
    (( hour >= 20 || hour < 7 ))
}

case "$mode" in
    on)
        echo "on" > "$state_file"
        start_filter
        notify-send -u low -e "Blue-light filter" "Enabled"
        ;;
    off | disable | disabled)
        echo "off" > "$state_file"
        stop_filter
        notify-send -u low -e "Blue-light filter" "Disabled"
        ;;
    auto)
        echo "auto" > "$state_file"
        if auto_active; then
            start_filter
            notify-send -u low -e "Blue-light filter" "Auto: enabled"
        else
            stop_filter
            notify-send -u low -e "Blue-light filter" "Auto: disabled"
        fi
        ;;
    *)
        echo "Usage: $0 on|auto|off" >&2
        exit 2
        ;;
esac
