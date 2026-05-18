#!/bin/bash

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Launch nvidia-settings in background, detached from the shell
nohup "$script_dir/gpu-run-safe.sh" nvidia-settings > /dev/null 2>&1 &
disown

# Send notification
notify-send -e -u low "NVIDIA Settings" "Launching..." -i nvidia-settings
