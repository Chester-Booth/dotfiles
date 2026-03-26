#!/bin/bash
# ~/.config/hypr/scripts/code-workspace-router.sh

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r event; do
    case "$event" in
        openwindow*)
            echo "[DEBUG] Raw event: $event" >&2

            addr="${event#*>>}"
            addr="${addr%%,*}"
            class=$(echo "$event" | cut -d',' -f3)

            echo "[DEBUG] Parsed addr: '${addr}' | class: '${class}'" >&2

            if [[ "$class" == "code" ]]; then
                is_floating=""
                for i in {1..10}; do
                    raw_clients=$(hyprctl clients -j)
                    
                    # Print all addresses currently known to hyprctl
                    echo "[DEBUG] Attempt $i — known addresses:" >&2
                    echo "$raw_clients" | jq -r '.[] | "\(.address) \(.class) \(.title) floating=\(.floating)"' >&2

                    is_floating=$(echo "$raw_clients" | \
                        jq -r --arg addr "0x${addr}" \
                        '.[] | select(.address == $addr) | .floating | tostring')

                    echo "[DEBUG] Attempt $i — looking for address '0x${addr}', got is_floating='${is_floating}'" >&2

                    [[ -n "$is_floating" ]] && break
                    sleep 0.05
                done

                echo "[DEBUG] Final is_floating='${is_floating}'" >&2

                if [[ "$is_floating" == "false" ]]; then
			        idea_open=$(hyprctl clients -j | \
			            jq -e '[.[] | select(.class | test("jetbrains-idea"))] | length > 0')

			        if [[ "$idea_open" == "true" ]]; then
			            hyprctl dispatch movetoworkspacesilent "4,address:0x${addr}"
			        else
			            hyprctl dispatch movetoworkspacesilent "2,address:0x${addr}"
			        fi
			        # floating windows: do nothing, let them open wherever Hyprland places them
			    fi
            fi
            ;;
    esac
done
