#!/bin/bash

# Launch nvidia-settings in background, detached from waybar
nohup gpu-run nvidia-settings > /dev/null 2>&1 &
disown

# Send notification
notify-send -e -u low "NVIDIA Settings" "Launching..." -i nvidia-settings
