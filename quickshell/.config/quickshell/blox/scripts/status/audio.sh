#!/usr/bin/env bash
set -u

sink_volume="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F'/' 'NR==1 { gsub(/[ %]/, "", $2); print $2 }')"
sink_mute="$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')"
source_mute="$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')"
sink_desc="$(pactl get-default-sink 2>/dev/null)"

[[ -n "$sink_volume" ]] || sink_volume=0
[[ -n "$sink_mute" ]] || sink_mute=yes
[[ -n "$source_mute" ]] || source_mute=yes

if [[ "$sink_mute" == "yes" ]]; then
    icon="󰝟"
elif ((sink_volume > 100)); then
    icon="󰝝"
elif (( sink_volume < 35 )); then
    icon="󰕿"
elif (( sink_volume < 70 )); then
    icon="󰖀"
else
    icon="󰕾"
fi

mic_icon="󰍬"
[[ "$source_mute" == "yes" ]] && mic_icon="󰍭"

jq -nc \
    --arg icon "$icon" \
    --arg micIcon "$mic_icon" \
    --arg sinkMute "$sink_mute" \
    --arg sourceMute "$source_mute" \
    --arg desc "$sink_desc" \
    --argjson volume "$sink_volume" \
    '{icon:$icon,micIcon:$micIcon,volume:$volume,muted:($sinkMute=="yes"),micMuted:($sourceMute=="yes"),tooltip:("Volume: \($volume)%\n\($desc)\nMic muted: \($sourceMute)")}'
