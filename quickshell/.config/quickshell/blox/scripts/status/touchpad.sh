#!/usr/bin/env bash
set -u

state_file="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell-touchpad-enabled"
enabled=true

if [[ -r "$state_file" ]]; then
	read -r enabled <"$state_file"
fi

case "$enabled" in
true) ;;
false) ;;
*) enabled=true ;;
esac

if [[ "$enabled" == "true" ]]; then
	jq -nc '{"icon":"󰟸","class":"enabled","enabled":true,"tooltip":"Touchpad enabled"}'
else
	jq -nc '{"icon":"󰤳","class":"disabled","enabled":false,"tooltip":"Touchpad disabled"}'
fi
