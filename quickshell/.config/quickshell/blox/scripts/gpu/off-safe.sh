#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=quickshell/.config/quickshell/blox/scripts/gpu/common.sh
source "$script_dir/common.sh" "$@"

if ! gpu_lock; then
	notify_gpu_busy
	exit 0
fi

if ! gpu_is_on; then
	exit 0
fi

if ! wait_for_gpu_nodes_idle; then
	gpu_notify -u normal -e "GPU Manager" "NVIDIA GPU is still in use; leaving it powered on." -i dialog-warning
	exit 1
fi

for module in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
	if module_loaded "$module" && ! sudo rmmod "$module"; then
		gpu_notify -u normal -e "GPU Manager" "Failed to unload ${module}; leaving the GPU powered on." -i dialog-warning
		exit 1
	fi
done

for module in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
	if module_loaded "$module"; then
		gpu_notify -u normal -e "GPU Manager" "NVIDIA modules are still loaded; skipping PCI remove." -i dialog-warning
		exit 1
	fi
done

if ! sudo /usr/local/bin/gpu-pci-remove; then
	gpu_notify -u normal -e "GPU Manager" "Failed to remove the NVIDIA GPU from the PCI bus." -i dialog-error
	exit 1
fi

gpu_notify -u normal -e "NVIDIA GPU powered off"
