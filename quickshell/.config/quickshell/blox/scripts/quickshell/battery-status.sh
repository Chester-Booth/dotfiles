#!/usr/bin/env bash
set -u

capacity="$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)"
status="$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)"

if [[ -z "${capacity:-}" ]]; then
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

jq -nc --arg icon "$icon" --arg class "$class" --arg status "$status" --argjson capacity "$capacity" \
    '{icon:$icon,class:$class,capacity:$capacity,tooltip:("Charge: \($capacity)%\n\($status)")}'
