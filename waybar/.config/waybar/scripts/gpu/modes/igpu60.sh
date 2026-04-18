#!/bin/bash

if ! ~/.config/waybar/scripts/gpu/gpu-off-safe.sh; then
    notify-send -u low "Eco Mode" "Failed to power off the NVIDIA GPU." -u critical -i dialog-error
    exit 1
fi

hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
asusctl profile set Quiet
notify-send -u low -e "Eco Mode" "iGPU + 60Hz enabled (Battery Saver)" -i power-profile-power-saver-symbolic
