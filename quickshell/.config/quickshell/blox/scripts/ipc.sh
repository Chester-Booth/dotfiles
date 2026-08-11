#!/usr/bin/env bash
set -euo pipefail

if (($# < 2)); then
	echo "Usage: ipc.sh <target> <function> [argument ...]" >&2
	exit 2
fi

config_file="${QUICKSHELL_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/blox}/shell.qml"

parent_quickshell_pid() {
	local process_id="$PPID"
	local process_name parent_id

	while [[ "$process_id" =~ ^[0-9]+$ ]] && ((process_id > 1)); do
		IFS= read -r process_name <"/proc/$process_id/comm" 2>/dev/null || break
		if [[ "$process_name" == "quickshell" ]]; then
			printf '%s\n' "$process_id"
			return 0
		fi

		parent_id="$(awk '{ print $4 }' "/proc/$process_id/stat" 2>/dev/null || true)"
		[[ "$parent_id" =~ ^[0-9]+$ ]] || break
		process_id="$parent_id"
	done

	return 1
}

registered_quickshell_pid() {
	quickshell list --all 2>/dev/null | awk -v config_file="$config_file" '
		/^Instance / {
			process_id = ""
			config_path = ""
		}
		/^  Process ID: / {
			process_id = $3
		}
		/^  Config path: / {
			config_path = substr($0, 16)
			if (config_path == config_file && process_id ~ /^[0-9]+$/) {
				print process_id
				exit
			}
		}
	'
}

main_pid="$(parent_quickshell_pid || registered_quickshell_pid)"
if [[ ! "$main_pid" =~ ^[0-9]+$ ]]; then
	echo "The Blox Quickshell instance is not running" >&2
	exit 1
fi

exec quickshell ipc --pid "$main_pid" call "$@"
