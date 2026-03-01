#!/bin/bash
# check for gcalcli
if ! command -v gcalcli &>/dev/null; then
    jq -nc '{"text":"󰃶","tooltip":"gcalcli not installed<br/><br/>install: pip install gcalcli<br/>configure: gcalcli init"}'
fi

# get todays agenda as day view
OUTPUT=$(timeout 10s gcalcli --nocolor agenda --nodeclined today tomorrow 2>/dev/null)
EXIT=$?

if [ $EXIT -eq 124 ]; then
    jq -nc '{"text":"󰃶","tooltip":"󰃶 Day view (today)<br/><br/>calendar loading timed out"}'
fi

if [ -z "$OUTPUT" ]; then
    jq -nc '{"text":"󰃶","tooltip":"󰃶 Day view (today)<br/><br/>No events today"}'
fi

day_html=$(printf "%s" "$OUTPUT" | sed 's/$/<br\/>/')
tooltip="󰃶 Day view (today)<br/><br/>$day_html"
jq -nc --arg tooltip "$tooltip" '{"text":"󰃶","tooltip":$tooltip}'