#!/bin/bash
gpu-off
hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
asusctl profile set Quiet
notify-send -u low -e "Eco Mode" "iGPU + 60Hz enabled (Battery Saver)" -i power-profile-power-saver-symbolic
