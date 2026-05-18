#!/bin/bash

set -u

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/eww-workspace-monitor.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

is_empty() {
    local ws=$1
    local count

    count=$(hyprctl clients -j 2>/dev/null | jq "[.[] | select(.workspace.id == $ws)] | length" 2>/dev/null) || return 1
    [[ $count -eq 0 ]]
}

manage_overlays() {
    local ws=$1

    if is_empty "$ws"; then
        eww open todo-overlay 2>/dev/null
        eww open gcal-overlay 2>/dev/null
    else
        eww close todo-overlay 2>/dev/null
        eww close gcal-overlay 2>/dev/null
    fi
}

current_workspace() {
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null
}

socket_path() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    printf '%s/hypr/%s/.socket2.sock\n' "$runtime_dir" "${HYPRLAND_INSTANCE_SIGNATURE:-}"
}

while true; do
    SOCKET="$(socket_path)"

    if [[ ! -S "$SOCKET" ]]; then
        sleep 1
        continue
    fi

    CURRENT_WS="$(current_workspace)"
    if [[ -n "$CURRENT_WS" ]]; then
        manage_overlays "$CURRENT_WS"
        echo "$CURRENT_WS"
    fi

    socat -U - UNIX-CONNECT:"$SOCKET" 2>/dev/null | while read -r line; do
        case $line in
            workspace\>\>*|openwindow\>\>*|closewindow\>\>*)
                CURRENT_WS="$(current_workspace)"
                if [[ -n "$CURRENT_WS" ]]; then
                    manage_overlays "$CURRENT_WS"
                    echo "$CURRENT_WS"
                fi
                ;;
        esac
    done

    sleep 1
done
