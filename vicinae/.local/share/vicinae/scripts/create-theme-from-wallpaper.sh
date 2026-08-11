#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title Create Theme from Current Wallpaper
# @vicinae.mode silent
# @vicinae.exec ["/bin/bash"]
# @vicinae.icon 🖼️
# @vicinae.keywords ["appearance", "colour", "matugen", "wallpaper"]
# @vicinae.description Open the Blox picker and generate an editable Matugen theme from the active wallpaper.
set -euo pipefail

exec "$HOME/.config/quickshell/blox/scripts/theme/picker-ipc.sh" generateCurrent
