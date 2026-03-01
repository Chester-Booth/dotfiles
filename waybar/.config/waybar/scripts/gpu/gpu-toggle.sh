#!/bin/bash

# Check if GPU is on
gpu_is_on() {
    lspci -s 01:00.0 2>/dev/null | grep -q "VGA"
}

# Get battery info
battery_percent=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

# Check if on battery and below 50%
on_battery_low() {
    if [ "$battery_status" != "Charging" ] && [ "$battery_percent" -lt 50 ]; then
        return 0
    else
        return 1
    fi
}

if gpu_is_on; then
    # Turn off GPU
    gpu-off
    notify-send -u low -e "GPU Manager" "NVIDIA GPU powered off" -i battery
else
    # Check battery before turning on
    if on_battery_low; then
        notify-send -u normal -e "GPU Manager" "Cannot enable GPU: Battery below 50% ($battery_percent%)"  -i battery-caution
        exit 1
    fi
    
    # Turn on GPU
    gpu-on
fi
