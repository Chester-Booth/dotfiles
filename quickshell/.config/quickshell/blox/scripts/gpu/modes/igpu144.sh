#!/bin/bash
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
notice="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/notice.sh"
gpu_osd="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/gpu-mode.sh"

battery_percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

if [ "$battery_status" != "Charging" ] && [ "$battery_percent" -lt 50 ]; then
	"$notice" "High refresh mode" "Battery below 50% ($battery_percent%)" "" "critical" 4500
	exit 1
fi

if ! "$script_dir/off-safe.sh"; then
	"$notice" "High refresh mode" "Failed to power off NVIDIA GPU" "" "critical" 4500
	exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@144,0x0,1
"$gpu_osd" "high-refresh"
