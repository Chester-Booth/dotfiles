#!/bin/bash

gpu_notifications_enabled=1

for gpu_arg in "$@"; do
    case "$gpu_arg" in
        --quiet|--no-notify)
            gpu_notifications_enabled=0
            ;;
    esac
done

gpu_lock() {
    local lock_file="${XDG_RUNTIME_DIR:-/tmp}/gpu-power.lock"

    exec 9>"$lock_file"
    flock -n 9
}

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

module_loaded() {
    lsmod | awk '{print $1}' | grep -qx "$1"
}

gpu_notify() {
    if (( gpu_notifications_enabled )); then
        notify-send "$@"
    fi
}

notify_gpu_busy() {
    gpu_notify -u normal -e "GPU Manager" "GPU power operation already in progress." -i dialog-information
}
