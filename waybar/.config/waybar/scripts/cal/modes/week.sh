#!/bin/bash
# check for gcalcli
if ! command -v gcalcli &>/dev/null; then
    jq -nc '{"text":"󰨴","tooltip":"gcalcli not installed<br/><br/>install: pip install gcalcli<br/>configure: gcalcli init"}'
    exit 0
fi

# get next 7 days
OUTPUT=$(timeout 15s gcalcli  agenda --nodeclined --nocolor today +7d 2>/dev/null)
EXIT=$?

if [ $EXIT -eq 124 ]; then
    jq -nc '{"text":"󰨴","tooltip":"󰨴 Week agenda<br/><br/>calendar loading timed out"}'
    exit 1
fi

if [ -z "$OUTPUT" ]; then
    jq -nc '{"text":"󰨴","tooltip":"󰨴 Week agenda<br/><br/>No events in the next 7 days"}'
    exit 0
fi

week_html=$(printf "%s" "$OUTPUT" | sed 's/$/<br\/>/')
tooltip="󰨴 Week agenda<br/><br/>$week_html"

jq -nc --arg tooltip "$tooltip" '{"text":"󰨳","tooltip":$tooltip}'


