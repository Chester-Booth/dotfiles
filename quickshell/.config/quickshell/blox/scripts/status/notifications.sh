#!/usr/bin/env bash
set -u

if ! command -v swaync-client >/dev/null 2>&1; then
    jq -nc '{"icon":"󰂜","class":"none","tooltip":"swaync-client unavailable"}'
    exit 0
fi

count="$(swaync-client -c 2>/dev/null || echo 0)"
dnd="$(swaync-client -D 2>/dev/null || echo false)"
inhibited="$(swaync-client -I 2>/dev/null || echo false)"

has_notification=false
[[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]] && has_notification=true

icon="󰂜"
class="none"
if [[ "$dnd" == "true" && "$inhibited" == "true" && "$has_notification" == "true" ]]; then
    icon="󰂛"; class="dnd-inhibited-notification"
elif [[ "$dnd" == "true" && "$inhibited" == "true" ]]; then
    icon="󰪑"; class="dnd-inhibited-none"
elif [[ "$inhibited" == "true" && "$has_notification" == "true" ]]; then
    icon="󰂛"; class="inhibited-notification"
elif [[ "$inhibited" == "true" ]]; then
    icon="󰪑"; class="inhibited-none"
elif [[ "$dnd" == "true" && "$has_notification" == "true" ]]; then
    icon="󰂠"; class="dnd-notification"
elif [[ "$dnd" == "true" ]]; then
    icon="󰪓"; class="dnd-none"
elif [[ "$has_notification" == "true" ]]; then
    icon="󱅫"; class="notification"
fi

jq -nc --arg icon "$icon" --arg class "$class" --arg dnd "$dnd" --arg inhibited "$inhibited" --argjson count "${count:-0}" \
    '{icon:$icon,class:$class,count:$count,dnd:($dnd=="true"),inhibited:($inhibited=="true"),tooltip:("\($count) notifications\nDND: \($dnd)\nInhibited: \($inhibited)")}'
