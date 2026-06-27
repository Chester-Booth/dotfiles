#!/usr/bin/env bash
set -u

CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/battery-status.json"

battery_dir=""
for candidate in /sys/class/power_supply/BAT*; do
	[[ -r "$candidate/capacity" ]] || continue
	battery_dir="$candidate"
	break
done

capacity=""
status=""
if [[ -n "$battery_dir" ]]; then
	read -r capacity <"$battery_dir/capacity" || capacity=""
	read -r status <"$battery_dir/status" || status="Unknown"
fi

if [[ ! "$capacity" =~ ^[0-9]+$ ]]; then
	if [[ -s "$CACHE_FILE" ]] && jq -e '.icon | type == "string"' "$CACHE_FILE" >/dev/null 2>&1 &&
		jq -e '.class | type == "string"' "$CACHE_FILE" >/dev/null 2>&1 &&
		jq -e '.status | type == "string"' "$CACHE_FILE" >/dev/null 2>&1; then
		cat "$CACHE_FILE"
		exit 0
	fi

	jq -nc '{"icon":"󰚥","class":"plugged","capacity":"","status":"Unknown","tooltip":"No battery detected"}'
	exit 0
fi

((capacity > 100)) && capacity=100

icon="󰁹"
class="normal"

if [[ "$status" == "Charging" ]]; then
	icons=(󰢟 󰢜 󰂆 󰂇 󰂈 󰢝 󰂉 󰢞 󰂊 󰂋 󰂅)
	index=$((capacity / 10))
	((index > 10)) && index=10
	icon="${icons[$index]}"
	class="charging"
elif [[ "$status" == "Full" || "$status" == "Not charging" ]]; then
	icon="󰂅"
	class="plugged"
elif ((capacity <= 10)); then
	icon="󰂃"
	class="critical"
else
	icons=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
	index=$((capacity / 10))
	((index > 9)) && index=9
	icon="${icons[$index]}"
fi

mkdir -p "$(dirname "$CACHE_FILE")"
json="$(jq -nc --arg icon "$icon" --arg class "$class" --arg status "$status" --argjson capacity "$capacity" \
	'{icon:$icon,class:$class,capacity:$capacity,status:$status,tooltip:("Charge: \($capacity)%\n\($status)")}')"
cache_tmp="${CACHE_FILE}.$$"
printf '%s\n' "$json" >"$cache_tmp"
mv -f "$cache_tmp" "$CACHE_FILE"
printf '%s\n' "$json"
