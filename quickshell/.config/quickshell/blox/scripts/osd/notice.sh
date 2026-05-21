#!/usr/bin/env bash
set -u

config_name="${QUICKSHELL_CONFIG_NAME:-blox}"
title="${1:-Status}"
message="${2:-}"
icon="${3:-󰋼}"
level="${4:-normal}"
duration="${5:-1200}"

quickshell ipc -c "$config_name" call osd notice "$title" "$message" "$icon" "$level" "$duration" >/dev/null 2>&1 || true
