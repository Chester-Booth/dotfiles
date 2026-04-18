#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/gpu-common.sh"

if ! gpu_lock; then
    notify_gpu_busy
    exit 0
fi

if ! gpu_is_on; then
    notify-send -u low -e "Powering on GPU"
    sudo /usr/local/bin/gpu-pci-rescan
    sleep 1.5
    sudo modprobe nvidia 2>/dev/null
    sudo modprobe nvidia_drm 2>/dev/null
    sudo modprobe nvidia_modeset 2>/dev/null
    sudo modprobe nvidia_uvm 2>/dev/null
    sleep 0.5
    notify-send -u low -e "NVIDIA GPU ready"
fi
