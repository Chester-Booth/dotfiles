#!/usr/bin/env bash

set -euo pipefail

if pgrep -x hyprsunset >/dev/null; then
  pkill -x hyprsunset
  notify-send -u low -e "Hyprsunset Off" "Blue-light filter disabled"
else
  hyprsunset >/dev/null 2>&1 &
  notify-send -u low -e "Hyprsunset On" "Blue-light filter enabled"
fi
