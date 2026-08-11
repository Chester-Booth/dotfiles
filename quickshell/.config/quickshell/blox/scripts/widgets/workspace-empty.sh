#!/usr/bin/env bash
set -u

workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"

if ! [[ "$workspace" =~ ^-?[0-9]+$ ]]; then
	jq -nc '{"workspace":null,"empty":false}'
	exit 0
fi

count="$(hyprctl clients -j 2>/dev/null | jq --argjson ws "$workspace" '[.[] | select(.workspace.id == $ws)] | length' 2>/dev/null || printf '1\n')"

if ! [[ "$count" =~ ^[0-9]+$ ]]; then
	count=1
fi

jq -nc --argjson workspace "$workspace" --argjson count "$count" '{"workspace":$workspace,"empty":($count == 0),"count":$count}'
