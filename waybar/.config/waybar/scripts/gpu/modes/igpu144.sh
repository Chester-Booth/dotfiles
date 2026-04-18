#!/bin/bash
battery_percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

if [ "$battery_status" != "Charging" ] && [ "$battery_percent" -lt 50 ]; then
    notify-send -u low "High Refresh Mode" "Cannot enable: Battery below 50% ($battery_percent%)" -u critical -i battery-caution
    exit 1
fi

if ! ~/.config/waybar/scripts/gpu/gpu-off-safe.sh; then
    notify-send -u low "High Refresh Mode" "Failed to power off the NVIDIA GPU." -u critical -i dialog-error
    exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@144,0x0,1
notify-send -u low -e "High Refresh Mode" "iGPU + 144Hz enabled" -i video-display-symbolic
