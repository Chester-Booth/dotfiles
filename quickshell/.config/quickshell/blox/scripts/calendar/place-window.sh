#!/usr/bin/env bash
set -euo pipefail

title=${1:?window title required}
window_width=${2:?window width required}
window_height=${3:?window height required}

address=""
for _ in 1 2 3 4 5; do
	address=$(hyprctl clients -j | jq -r --arg title "$title" '[.[] | select(.title == $title)] | last | .address // empty')
	[[ -n "$address" ]] && break
	sleep 0.04
done
[[ -n "$address" ]] || exit 1

read -r cursor_x cursor_y < <(hyprctl cursorpos | tr -d ',' | awk '{print $1, $2}')
read -r monitor_x monitor_y monitor_width monitor_height < <(
	hyprctl monitors -j | jq -r --argjson x "$cursor_x" --argjson y "$cursor_y" '
        [.[] | select($x >= .x and $x < .x + .width and $y >= .y and $y < .y + .height)][0]
        | [.x, .y, .width, .height] | @tsv'
)

gap=8
popup_width=360
bar_gap=42
if ((cursor_x < monitor_x + monitor_width / 2)); then
	target_x=$((monitor_x + popup_width + gap + 8))
else
	target_x=$((monitor_x + monitor_width - popup_width - gap - window_width - 8))
fi
target_y=$((monitor_y + bar_gap))
((target_y + window_height > monitor_y + monitor_height - 8)) && target_y=$((monitor_y + monitor_height - window_height - 8))

hyprctl dispatch "hl.dsp.window.float({ action = \"on\", window = \"address:${address}\" })"
hyprctl dispatch "hl.dsp.window.resize({ x = ${window_width}, y = ${window_height}, relative = false, window = \"address:${address}\" })"
hyprctl dispatch "hl.dsp.window.move({ x = ${target_x}, y = ${target_y}, relative = false, window = \"address:${address}\" })"
hyprctl dispatch "hl.dsp.window.pin({ action = \"on\", window = \"address:${address}\" })"
