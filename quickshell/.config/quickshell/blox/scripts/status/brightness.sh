#!/usr/bin/env bash
set -u

device="${1:-amdgpu_bl1}"
state_file="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/blue-light-mode"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
percent="$(brightnessctl -d "$device" -m 2>/dev/null | awk -F, '{gsub(/%/, "", $4); print $4}')"
[[ -n "$percent" ]] || percent=0

icons=(󰃚 󰃛 󰃜 󰃝 󰃞 󰃟 󰃠)
index=$((percent / 17))
((index > 6)) && index=6

blue_mode="auto"
[[ -r "$state_file" ]] && read -r blue_mode <"$state_file"
case "$blue_mode" in
on | auto | off) ;;
*) blue_mode="auto" ;;
esac

blue_active="$("$script_dir/display/blue-light-active.sh" 2>/dev/null || printf 'false')"

jq -nc \
	--arg icon "${icons[$index]}" \
	--arg blueMode "$blue_mode" \
	--argjson percent "$percent" \
	--argjson blueActive "$blue_active" \
	'{icon:$icon,percent:$percent,blueLightMode:$blueMode,blueLightActive:$blueActive,tooltip:("Brightness: \($percent)%\nBlue light: \($blueMode)" + (if $blueActive then " active" else " inactive" end))}'
