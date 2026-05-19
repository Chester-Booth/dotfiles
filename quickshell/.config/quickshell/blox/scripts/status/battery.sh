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
    read -r capacity < "$battery_dir/capacity" || capacity=""
    read -r status < "$battery_dir/status" || status="Unknown"
fi

if [[ ! "$capacity" =~ ^[0-9]+$ ]]; then
    if [[ -s "$CACHE_FILE" ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi

    jq -nc '{"icon":"󰚥","class":"plugged","capacity":"","tooltip":"No battery detected"}'
    exit 0
fi

icon="󰁹"
class="normal"

if [[ "$status" == "Charging" ]]; then
    icon="󰂄"
    class="charging"
elif [[ "$status" == "Full" || "$status" == "Not charging" ]]; then
    icon="󰚥"
    class="plugged"
elif (( capacity <= 10 )); then
    icon="󰂃"
    class="critical"
else
    icons=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
    index=$((capacity / 10))
    (( index > 9 )) && index=9
    icon="${icons[$index]}"
fi

mkdir -p "$(dirname "$CACHE_FILE")"
jq -nc --arg icon "$icon" --arg class "$class" --arg status "$status" --argjson capacity "$capacity" \
    '{icon:$icon,class:$class,capacity:$capacity,tooltip:("Charge: \($capacity)%\n\($status)")}' | tee "$CACHE_FILE"
