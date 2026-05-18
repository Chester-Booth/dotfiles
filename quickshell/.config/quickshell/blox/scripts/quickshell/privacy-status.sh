#!/usr/bin/env bash
set -u

screenshares="$(hyprctl clients -j 2>/dev/null | jq '[.[] | select((.title // "" | test("screen|share|portal"; "i")) or (.class // "" | test("xdg-desktop-portal"; "i")))] | length' 2>/dev/null || echo 0)"

if [[ "$screenshares" =~ ^[0-9]+$ && "$screenshares" -gt 0 ]]; then
    jq -nc --argjson count "$screenshares" '{"icon":"󰍹","class":"active","tooltip":("\($count) possible privacy sessions")}'
else
    jq -nc '{"icon":"󰍹","class":"idle","tooltip":"No privacy sessions detected"}'
fi
