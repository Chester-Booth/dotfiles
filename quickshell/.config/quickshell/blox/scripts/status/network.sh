#!/usr/bin/env bash
set -u

wifi="$(nmcli -t -f WIFI general 2>/dev/null || echo disabled)"
active="$(nmcli -t -f ACTIVE,SSID,SIGNAL,FREQ,DEVICE dev wifi 2>/dev/null | awk -F: '$1=="yes"{print; exit}')"

if [[ "$wifi" != "enabled" ]]; then
    jq -nc '{"icon":"󰤭","class":"disabled","tooltip":"Wi-Fi disabled"}'
    exit 0
fi

if [[ -z "$active" ]]; then
    jq -nc '{"icon":"󰤩","class":"disconnected","tooltip":"Wi-Fi disconnected"}'
    exit 0
fi

IFS=: read -r _ ssid signal freq device <<< "$active"
signal="${signal:-0}"
icons=(󰤯 󰤟 󰤢 󰤥 󰤨)
index=$((signal / 25))
(( index > 4 )) && index=4

jq -nc --arg icon "${icons[$index]}" --arg ssid "$ssid" --arg freq "$freq" --arg device "$device" --argjson signal "$signal" \
    '{icon:$icon,class:"wifi",ssid:$ssid,signal:$signal,tooltip:("\($ssid)\nSignal: \($signal)%\n\($freq) MHz\n\($device)")}'
