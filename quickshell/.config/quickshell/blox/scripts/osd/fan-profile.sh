#!/usr/bin/env bash
set -u

config_name="${QUICKSHELL_CONFIG_NAME:-blox}"
profile="${1:-balanced}"

quickshell ipc -c "$config_name" call osd fan "$profile" >/dev/null 2>&1 || true
