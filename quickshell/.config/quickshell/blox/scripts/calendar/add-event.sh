#!/usr/bin/env bash
set -u

day="${1:-$(date +%F)}"
title="${2:-}"

if [ -z "$title" ]; then
    exit 0
fi

if command -v gcalcli >/dev/null 2>&1; then
    gcalcli add --title "$title" --when "$day 09:00" --duration 60 >/dev/null 2>&1 || true
fi
