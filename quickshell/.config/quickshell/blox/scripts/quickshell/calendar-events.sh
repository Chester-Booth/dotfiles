#!/usr/bin/env bash
set -u

day="${1:-$(date +%F)}"

if ! command -v gcalcli >/dev/null 2>&1; then
    jq -nc --arg day "$day" '{"date":$day,"events":[],"raw":"gcalcli is not installed"}'
    exit 0
fi

next_day="$(date -d "$day + 1 day" +%F 2>/dev/null || date +%F)"
raw="$(timeout 12s gcalcli --nocolor agenda "$day" "$next_day" 2>/dev/null || true)"

if [ -z "$raw" ]; then
    jq -nc --arg day "$day" '{"date":$day,"events":[],"raw":"No events"}'
else
    jq -nc --arg day "$day" --arg raw "$raw" '{"date":$day,"events":($raw | split("\n") | map(select(length > 0))),"raw":$raw}'
fi
