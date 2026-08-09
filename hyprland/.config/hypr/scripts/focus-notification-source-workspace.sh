#!/usr/bin/env bash

set -euo pipefail

app_name="${BLOX_NOTIFICATION_APP_NAME:-}"
desktop_entry="${BLOX_NOTIFICATION_DESKTOP_ENTRY:-}"
window_address="${BLOX_NOTIFICATION_WINDOW_ADDRESS:-}"
sender_pid="${BLOX_NOTIFICATION_SENDER_PID:-}"

if [[ -z "$app_name" && -z "$desktop_entry" && -z "$window_address" && -z "$sender_pid" ]]; then
    exit 0
fi

if [[ ! "$window_address" =~ ^0x[0-9a-fA-F]+$ ]]; then
    window_address=""
fi
if [[ ! "$sender_pid" =~ ^[0-9]+$ ]]; then
    sender_pid=""
fi

clients_json="$(hyprctl clients -j 2>/dev/null || true)"
if [[ -z "$clients_json" || "$clients_json" == "[]" ]]; then
    exit 0
fi

match="$(
    jq -r \
        --arg app "$app_name" \
        --arg desktop "$desktop_entry" \
        --arg address "$window_address" \
        --argjson pid "${sender_pid:-0}" '
        def norm:
            tostring
            | ascii_downcase
            | sub("\\.desktop$"; "")
            | gsub("[^a-z0-9]"; "");

        def last_segment:
            tostring
            | sub("\\.desktop$"; "")
            | split(".")
            | .[-1];

        def candidates:
            [$app, $desktop, ($app | last_segment), ($desktop | last_segment)]
            | map(norm)
            | unique
            | map(select(length > 1));

        def client_score($candidates):
            . as $client
            | ($client.class // "" | norm) as $class
            | ($client.initialClass // "" | norm) as $initial_class
            | ($client.title // "" | norm) as $title
            | ($client.initialTitle // "" | norm) as $initial_title
            | [
                $candidates[]
                | . as $candidate
                | if $class == $candidate or $initial_class == $candidate then
                    100
                  elif ($class | contains($candidate)) and ($candidate | length > 2) then
                    80
                  elif ($initial_class | contains($candidate)) and ($candidate | length > 2) then
                    70
                  elif (($title | contains($candidate)) or ($initial_title | contains($candidate))) and ($candidate | length > 2) then
                    40
                  else
                    0
                  end
              ]
            | max;

        candidates as $candidates
        | [
            .[]
            | .score = (
                if $address != "" and (.address // "") == $address then 1000
                elif $pid > 0 and (.pid // 0) == $pid then 900
                elif $address != "" or $pid > 0 then 0
                else client_score($candidates)
                end
              )
            | select(.score > 0)
          ]
        | sort_by(-.score, (.focusHistoryID // 999999))
        | .[0]
        | select(. != null)
        | "\(.workspace.id // "") \(.address // "") \(.class // "") \(.title // "")"
        ' <<<"$clients_json"
)"

if [[ -z "$match" || "$match" == "null" ]]; then
    exit 0
fi

read -r workspace_id address _ <<<"$match"
if [[ -z "$address" || "$address" == "null" ]]; then
    exit 0
fi

if [[ "${FOCUS_NOTIFICATION_DRY_RUN:-}" == "1" ]]; then
    printf 'workspace=%s address=%s source_app=%s desktop_entry=%s\n' \
        "$workspace_id" "$address" "$app_name" "$desktop_entry"
    exit 0
fi

# Focusing a window also changes to its workspace. Hyprland 0.55 replaced
# the old `focuswindow` dispatcher arguments with this Lua form.
hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })" >/dev/null
