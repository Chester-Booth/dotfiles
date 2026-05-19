#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
state_file="$state_dir/blue-light-mode"
mkdir -p "$state_dir"

if pgrep -x hyprsunset >/dev/null; then
  echo "off" > "$state_file"
  pkill -x hyprsunset
  notify-send -u low -e "Hyprsunset Off" "Blue-light filter disabled"
else
  echo "on" > "$state_file"
  hyprsunset >/dev/null 2>&1 &
  notify-send -u low -e "Hyprsunset On" "Blue-light filter enabled"
fi
