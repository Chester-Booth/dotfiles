#!/bin/bash
# check for gcalcli
if ! command -v gcalcli &>/dev/null; then
    jq -nc '{"text":"󰨴","tooltip":"gcalcli not installed<br/><br/>install: pip install gcalcli<br/>configure: gcalcli init"}'
    exit 0
fi

# get todays agenda
OUTPUT=$(timeout 10s gcalcli  agenda --nodeclined --nocolor today tomorrow 2>/dev/null)
EXIT=$?

if [ $EXIT -eq 124 ]; then
    jq -nc '{"text":"󰨴","tooltip":"󰨴 Agenda (today)<br/><br/>calendar loading timed out"}'
    exit 1
fi

if [ -z "$OUTPUT" ]; then
    jq -nc '{"text":"󰨴","tooltip":"󰨴 Agenda (today)<br/><br/>No events today"}'
    exit 0
fi

agenda_html=$(printf "%s" "$OUTPUT" | sed 's/$/<br\/>/')
tooltip="󰨴 Agenda (today)<br/><br/>$agenda_html"

jq -nc --arg tooltip "$tooltip" '{"text":"󰨴","tooltip":$tooltip}'