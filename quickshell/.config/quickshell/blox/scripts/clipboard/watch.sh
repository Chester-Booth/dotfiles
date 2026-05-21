#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/state.py" capture || true
exec wl-paste --watch "$script_dir/state.py" capture
