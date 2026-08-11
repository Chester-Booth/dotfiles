#!/usr/bin/env sh

set -eu

if pgrep -x orca >/dev/null 2>&1; then
	pkill -x orca
	notify-send -u low -i preferences-desktop-accessibility "Orca disabled"
else
	orca --replace >/dev/null 2>&1 &
	notify-send -u low -i preferences-desktop-accessibility "Orca enabled"
fi
