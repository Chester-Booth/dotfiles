#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
notice="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/notice.sh"
# shellcheck source=quickshell/.config/quickshell/blox/scripts/gpu/common.sh
source "$script_dir/common.sh"

if ! gpu_lock; then
	notify_gpu_busy
	exit 0
fi

if ! gpu_is_on; then
	"$notice" "GPU" "Powering on" "󰢮" "normal" 4500
	sudo /usr/local/bin/gpu-pci-rescan
	sleep 1.5
	sudo modprobe nvidia 2>/dev/null
	sudo modprobe nvidia_drm 2>/dev/null
	sudo modprobe nvidia_modeset 2>/dev/null
	sudo modprobe nvidia_uvm 2>/dev/null
	sleep 0.5
	"$notice" "GPU" "NVIDIA GPU ready" "󰢮" "normal" 4500
fi
