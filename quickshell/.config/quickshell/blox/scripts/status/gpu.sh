#!/bin/bash

# Check if GPU is on - check for VGA controller
gpu_is_on() {
    lspci -s 01:00.0 2>/dev/null | grep -q "VGA"
}

# Check current refresh rate
current_rr=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].refreshRate' 2>/dev/null | cut -d. -f1)
[ -z "$current_rr" ] && current_rr="60"

if gpu_is_on; then
    if [ "$current_rr" = "144" ]; then
        icon="󰪫"
        text="GAMING"
        class="gaming"
        tooltip="Gaming Mode\nGPU: ON | 144Hz"
    else
        icon="󰢮"
        text="PERF"
        class="performance"
        tooltip="Performance Mode\nGPU: ON | ${current_rr}Hz"
    fi
else
    if [ "$current_rr" = "144" ]; then
        icon=""
        text="144Hz"
        class="high-refresh"
        tooltip="High Refresh Only\nGPU: OFF | 144Hz"
    else
        icon="󰌪"
        text="ECO"
        class="eco"
        tooltip="Eco Mode\nGPU: OFF | ${current_rr}Hz"
    fi
fi

echo "{\"text\":\"$text\",\"alt\":\"$class\",\"tooltip\":\"$tooltip\",\"class\":\"$class\"}"
