#!/usr/bin/env bash
# Event-driven Hyprland workspace display for Waybar
# Updates only when Hyprland state changes (more efficient than polling)

# Path to the Python script
SCRIPT_PATH="$HOME/.config/waybar/scripts/hyprland-workspaces.py"

# Initial output
python3 "$SCRIPT_PATH"

# Listen to Hyprland socket for events
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    # Update on relevant events:
    # - workspace>> (workspace change)
    # - activewindow>> (window focus change)
    # - openwindow>> (new window)
    # - closewindow>> (window closed)
    # - movewindow>> (window moved between workspaces)
    case "$line" in
        workspace\>\>*|activewindow\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*)
            python3 "$SCRIPT_PATH"
            ;;
    esac
done