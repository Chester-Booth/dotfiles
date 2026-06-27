#!/usr/bin/env bash
set -u

day="${1:-$(date +%F)}"

if ! command -v gcalcli >/dev/null 2>&1; then
	jq -nc --arg day "$day" '{"date":$day,"events":[],"raw":"gcalcli is not installed","ok":false,"error":"gcalcli is not installed"}'
	exit 0
fi

next_day="$(date -d "$day + 1 day" +%F 2>/dev/null || date +%F)"
raw="$(timeout 12s gcalcli --nocolor agenda "$day" "$next_day" 2>&1)"
status=$?

if ((status != 0)); then
	if ((status == 124)); then
		error="Calendar request timed out"
	else
		error="$(awk 'NF { line=$0 } END { print line }' <<<"$raw")"
		[[ -n "$error" ]] || error="Calendar request failed with exit code $status"
	fi

	jq -nc --arg day "$day" --arg error "$error" \
		'{date:$day,events:[],raw:$error,ok:false,error:$error}'
	exit 0
fi

if [ -z "$raw" ]; then
	jq -nc --arg day "$day" '{"date":$day,"events":[],"raw":"No events","ok":true,"error":""}'
else
	jq -nc --arg day "$day" --arg raw "$raw" \
		'{date:$day,events:($raw | split("\n") | map(select(length > 0))),raw:$raw,ok:true,error:""}'
fi
