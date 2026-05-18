#!/usr/bin/env bash
set -u

device="${1:-amdgpu_bl1}"
percent="$(brightnessctl -d "$device" -m 2>/dev/null | awk -F, '{gsub(/%/, "", $4); print $4}')"
[[ -n "$percent" ]] || percent=0

icons=(󰃚 󰃛 󰃜 󰃝 󰃞 󰃟 󰃠)
index=$((percent / 17))
(( index > 6 )) && index=6

jq -nc --arg icon "${icons[$index]}" --argjson percent "$percent" \
    '{icon:$icon,percent:$percent,tooltip:("Brightness: \($percent)%")}'
