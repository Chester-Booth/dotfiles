#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title Apply Theme
# @vicinae.mode fullOutput
# @vicinae.exec ["/bin/bash"]
# @vicinae.icon 🎨
# @vicinae.argument1 { "type": "text", "placeholder": "stable theme ID" }
# @vicinae.keywords ["appearance", "colour", "theme"]
# @vicinae.description Validate and apply a saved Blox theme.
set -euo pipefail

repo_root=$(git -C "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" rev-parse --show-toplevel)
exec "$repo_root/themes/bin/themectl" apply "$1" --json
