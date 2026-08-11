#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title Open Theme Picker
# @vicinae.mode silent
# @vicinae.exec ["/bin/bash"]
# @vicinae.icon 🎨
# @vicinae.keywords ["appearance", "colour", "themes"]
# @vicinae.description Open the full Blox theme picker inside Quickshell.
set -euo pipefail

exec "$HOME/.config/quickshell/blox/scripts/theme/picker-ipc.sh" open
