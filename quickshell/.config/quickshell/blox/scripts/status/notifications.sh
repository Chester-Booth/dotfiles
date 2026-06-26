#!/usr/bin/env bash
set -u

owner="$(busctl --user --no-pager --list 2>/dev/null | awk '$1 == "org.freedesktop.Notifications" { print $3; exit }')"

if [[ -z "${owner:-}" || "$owner" == "-" ]]; then
    jq -nc '{"icon":"󰂜","class":"none","count":0,"dnd":false,"inhibited":false,"tooltip":"No notification daemon registered"}'
    exit 0
fi

icon="󰂜"
class="none"
tooltip="Notifications provided by ${owner}"

if [[ "$owner" == "quickshell" ]]; then
    tooltip="Notifications provided by Quickshell"
fi

jq -nc --arg icon "$icon" --arg class "$class" --arg tooltip "$tooltip" \
    '{icon:$icon,class:$class,count:0,dnd:false,inhibited:false,tooltip:$tooltip}'
