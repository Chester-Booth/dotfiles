#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

zen-browser calendar.google.com >/dev/null 2>&1 || true
hyprctl dispatch workspace 1 >/dev/null 2>&1 || true
"$SCRIPT_DIR/../waybar/todo/update_gcal_md.sh" >/dev/null 2>&1 || true
