#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

zen-browser calendar.google.com
hyprctl dispatch workspace 1
"$SCRIPT_DIR/../waybar/todo/update_gcal_md.sh"
