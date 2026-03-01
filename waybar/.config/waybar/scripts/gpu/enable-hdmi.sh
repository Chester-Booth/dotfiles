#!/bin/bash

# Ensure GPU is on
gpu-on
sleep 1

# Check current modeset status
CURRENT_MODESET=$(sudo cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo "N")

if [ "$CURRENT_MODESET" = "N" ]; then
    ~/.config/hypr/scripts/switch-to-hdmi-mode.sh
else
    notify-send "HDMI Mode" "Already enabled" -i video-display
fi
