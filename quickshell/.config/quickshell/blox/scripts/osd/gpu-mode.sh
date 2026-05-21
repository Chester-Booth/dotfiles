#!/usr/bin/env bash
set -u

config_name="${QUICKSHELL_CONFIG_NAME:-blox}"
mode="${1:-eco}"

quickshell ipc -c "$config_name" call osd gpu "$mode" >/dev/null 2>&1 || true
