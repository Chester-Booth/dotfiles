#!/usr/bin/env bash
set -euo pipefail

day="${1:-$(date +%F)}"
title="${2:-}"

if [ -z "$title" ]; then
	exit 0
fi

if ! command -v gcalcli >/dev/null 2>&1; then
	echo "gcalcli is not installed" >&2
	exit 127
fi

timeout 30s gcalcli add --title "$title" --when "$day 09:00" --duration 60 >/dev/null
