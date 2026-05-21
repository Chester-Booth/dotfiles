#!/usr/bin/env bash
set -u

config_name="${QUICKSHELL_CONFIG_NAME:-blox}"
mode="${1:-auto}"
active="${2:-}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$active" ]]; then
	active="$("$script_dir/display/blue-light-active.sh" 2>/dev/null || printf 'false')"
fi

quickshell ipc -c "$config_name" call osd blueLight "$mode" "$active" >/dev/null 2>&1 || true
