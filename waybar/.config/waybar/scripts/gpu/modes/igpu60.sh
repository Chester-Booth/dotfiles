#!/bin/bash

gpu_off_args=()
mode_notifications_enabled=1

if [[ "${1:-}" == "--quiet" || "${1:-}" == "--no-notify" ]]; then
    gpu_off_args=("$1")
    mode_notifications_enabled=0
fi

mode_notify() {
    if (( mode_notifications_enabled )); then
        notify-send "$@"
    fi
}

if ! ~/.config/waybar/scripts/gpu/gpu-off-safe.sh "${gpu_off_args[@]}"; then
    mode_notify -u low "Eco Mode" "Failed to power off the NVIDIA GPU." -u critical -i dialog-error
    exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
asusctl profile set Quiet
mode_notify -u low -e "Eco Mode" "iGPU + 60Hz enabled (Battery Saver)" -i power-profile-power-saver-symbolic
