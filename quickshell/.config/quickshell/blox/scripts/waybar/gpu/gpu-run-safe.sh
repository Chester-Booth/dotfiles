#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

gpu_is_on() {
    lspci -s 01:00.0 2>/dev/null | grep -q "VGA"
}

gpu_nodes_in_use() {
    local nodes=()

    shopt -s nullglob
    nodes=(/dev/nvidia*)
    shopt -u nullglob

    ((${#nodes[@]} > 0)) || return 1
    sudo fuser "${nodes[@]}" &>/dev/null
}

if ! gpu_is_on; then
    "$script_dir/gpu-on-safe.sh" || exit 1
fi

__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json \
"$@"

exit_code=$?

(
    sleep 2
    if ! gpu_nodes_in_use; then
        "$script_dir/gpu-off-safe.sh" >/dev/null 2>&1
    fi
) &

exit "$exit_code"
