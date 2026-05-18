#!/usr/bin/env bash
set -u

show="$(bluetoothctl show 2>/dev/null || true)"
powered="$(awk -F': ' '/Powered:/ {print $2; exit}' <<< "$show")"
connected="$(bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [^ ]* //' | paste -sd ', ' -)"

if [[ -z "$show" ]]; then
    jq -nc '{"icon":"󰂯","class":"none","tooltip":"No Bluetooth controller"}'
elif [[ "$powered" != "yes" ]]; then
    jq -nc '{"icon":"󰂲","class":"disabled","tooltip":"Bluetooth off"}'
elif [[ -n "$connected" ]]; then
    jq -nc --arg connected "$connected" '{"icon":"󰂱","class":"connected","tooltip":("Connected:\n" + $connected)}'
else
    jq -nc '{"icon":"󰂯","class":"on","tooltip":"Bluetooth on"}'
fi
