#!/bin/bash
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
notice="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/notice.sh"
gpu_osd="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/gpu-mode.sh"

gpu_off_args=()
mode_notifications_enabled=1

if [[ "${1:-}" == "--quiet" || "${1:-}" == "--no-notify" ]]; then
	gpu_off_args=("$1")
	mode_notifications_enabled=0
fi

mode_notify() {
	if ((mode_notifications_enabled)); then
		"$notice" "$@"
	fi
}

if ! "$script_dir/off-safe.sh" "${gpu_off_args[@]}"; then
	mode_notify "Eco mode" "Failed to power off NVIDIA GPU" "󰌪" "critical" 4500
	exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
asusctl profile set Quiet
if ((mode_notifications_enabled)); then
	"$gpu_osd" "eco"
fi
