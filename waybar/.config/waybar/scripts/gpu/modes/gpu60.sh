#!/bin/bash
battery_percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

if [ "$battery_status" != "Charging" ] && [ "$battery_percent" -lt 50 ]; then
    notify-send -u low "Performance Mode" "Cannot enable: Battery below 50% ($battery_percent%)" -u critical -i battery-caution
    exit 1
fi

if ! ~/.config/waybar/scripts/gpu/gpu-on-safe.sh; then
    notify-send -u low "Performance Mode" "Failed to enable the NVIDIA GPU." -u critical -i dialog-error
    exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
notify-send -u low -e "Performance Mode" "GPU ON + 60Hz enabled" -i power-profile-performance-symbolic
