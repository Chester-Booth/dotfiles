#!/usr/bin/env bash
set -u

lock_file="${XDG_RUNTIME_DIR:-/tmp}/quickshell-kbd-backlight.watch.lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

service="org.freedesktop.UPower"
path="/org/freedesktop/UPower/KbdBacklight"
interface="org.freedesktop.UPower.KbdBacklight"

max="$(
	gdbus call --system \
		--dest "$service" \
		--object-path "$path" \
		--method "$interface.GetMaxBrightness" 2>/dev/null |
		awk -F'[(), ]+' '{print $2}'
)"

[[ "$max" =~ ^[0-9]+$ && "$max" -gt 0 ]] || exit 0

gdbus monitor --system --dest "$service" --object-path "$path" 2>/dev/null |
	awk -v max="$max" '
		/BrightnessChangedWithSource/ {
			value = $0
			sub(/^.*BrightnessChangedWithSource \(/, "", value)
			sub(/,.*$/, "", value)
			if (value ~ /^[0-9]+$/) {
				printf("{\"value\":%d,\"max\":%d}\n", value, max)
				fflush()
			}
		}
	'
