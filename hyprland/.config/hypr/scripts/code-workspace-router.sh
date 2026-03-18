#!/bin/bash
# ~/.config/hypr/scripts/code-workspace-router.sh

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r event; do
    case "$event" in
        openwindow*)
            addr="${event#*>>}"
            addr="${addr%%,*}"
            class=$(echo "$event" | cut -d',' -f3)

            if [[ "$class" == "code" ]]; then
                idea_open=$(hyprctl clients -j | \
                    jq -e '[.[] | select(.class | test("jetbrains-idea"))] | length > 0')

                if [[ "$idea_open" == "true" ]]; then
                    hyprctl dispatch movetoworkspacesilent "4,address:0x${addr}"
                fi
            fi
            ;;
    esac
done