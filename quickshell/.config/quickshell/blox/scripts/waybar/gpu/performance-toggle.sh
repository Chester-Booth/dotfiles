#!/bin/bash

notify-send "performance-toggle.sh" "Script executed" -i info

# Get current refresh rate
current_rr=$(hyprctl monitors -j | jq -r '.[0].refreshRate' | cut -d. -f1)

# Get battery info
battery_percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

# Check if GPU is on
gpu_is_on() {
    lspci -s 01:00.0 2>/dev/null | grep -q "VGA"
}

on_battery_low() {
    if [ "$battery_status" != "Charging" ] && [ "$battery_percent" -lt 50 ]; then
        return 0
    else
        return 1
    fi
}

if [ "$current_rr" -eq 60 ]; then
    # Switching to performance mode
    if on_battery_low; then
        notify-send -u normal -e "Performance Mode" "Cannot enable: Battery below 50% ($battery_percent%)"  -i battery-caution
        exit 1
    fi
    
    # Enable 144Hz
    hyprctl keyword monitor eDP-1,1920x1080@144,0x0,1
    
    # Optionally turn on GPU
    # gpu-on
    
    notify-send -u low -e "Performance Mode" "144Hz enabled" -i video-display
else
    # Switching to battery saver
    hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
    
    # Optionally turn off GPU
    # gpu-off
    
    notify-send -u low -e "Battery Saver" "60Hz enabled" -i battery
fi
