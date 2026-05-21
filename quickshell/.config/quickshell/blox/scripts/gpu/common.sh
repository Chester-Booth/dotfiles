#!/bin/bash

gpu_notifications_enabled=1
gpu_notice="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox/scripts/osd/notice.sh"

for gpu_arg in "$@"; do
	case "$gpu_arg" in
	--quiet | --no-notify)
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

wait_for_gpu_nodes_idle() {
	local attempts="${1:-10}"
	local delay="${2:-0.2}"
	local i

	for ((i = 0; i < attempts; i++)); do
		if ! gpu_nodes_in_use; then
			return 0
		fi
		sleep "$delay"
	done

	return 1
}

module_loaded() {
	lsmod | awk '{print $1}' | grep -qx "$1"
}

gpu_notify() {
	if ((gpu_notifications_enabled)); then
		local title="GPU Manager"
		local message=""
		local icon="󰢮"
		local level="normal"
		local args=()

		while (($#)); do
			case "$1" in
			-u)
				shift
				case "${1:-normal}" in
				critical) level="critical" ;;
				normal) level="warning" ;;
				*) level="normal" ;;
				esac
				;;
			-i)
				shift
				;;
			-e)
				;;
			-*)
				;;
			*)
				args+=("$1")
				;;
			esac
			shift
		done

		((${#args[@]} >= 1)) && title="${args[0]}"
		((${#args[@]} >= 2)) && message="${args[1]}"
		"$gpu_notice" "$title" "$message" "$icon" "$level" 4500
	fi
}

notify_gpu_busy() {
	gpu_notify -u normal -e "GPU Manager" "GPU power operation already in progress." -i dialog-information
}
