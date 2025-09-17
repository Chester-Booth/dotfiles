#!/bin/bash
# simple power menu with wofi
chosen=$(printf " lock\n⏻ shutdown\n reboot\n sleep\n hibernate" | wofi --dmenu --cache-file=/dev/null)

case "$chosen" in
  " lock") hyprlock ;;
  "⏻ shutdown") systemctl poweroff ;;
  " reboot") systemctl reboot ;;
  " sleep") systemctl suspend-then-hibernate ;;
  " hibernate") systemctl hibernate ;;
esac
