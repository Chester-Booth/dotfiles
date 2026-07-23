#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=quickshell/.config/quickshell/blox/scripts/gpu/common.sh
source "$script_dir/common.sh" "$@"

if ! gpu_lock; then
	notify_gpu_busy
	exit 75
fi

if ! gpu_is_on; then
	exit 0
fi

if ! wait_for_gpu_nodes_idle; then
	busy_processes="$(gpu_busy_processes || true)"
	if [[ -n "$busy_processes" ]]; then
		message="NVIDIA GPU is in use by ${busy_processes}; close it and try Eco mode again."
	else
		message="NVIDIA GPU is still in use; close GPU applications and try Eco mode again."
	fi
	printf '%s\n' "$message" >&2
	gpu_notify -u normal -e "GPU Manager" "$message" -i dialog-warning
	exit 1
fi

for module in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
	if module_loaded "$module" && ! unload_module "$module"; then
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
