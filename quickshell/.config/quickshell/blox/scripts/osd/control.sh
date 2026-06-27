#!/usr/bin/env bash
set -u

script_root="${QUICKSHELL_SCRIPT_ROOT:-$HOME/.config/quickshell/blox/scripts}"
config_name="${QUICKSHELL_CONFIG_NAME:-blox}"
brightness_device="${BRIGHTNESS_DEVICE:-amdgpu_bl1}"
keyboard_device="${KEYBOARD_BRIGHTNESS_DEVICE:-asus::kbd_backlight}"
camera_device="${CAMERA_DEVICE:-asus::camera}"
mic_led_device="${MIC_LED_DEVICE:-platform::micmute}"
touchpad_device="${TOUCHPAD_DEVICE:-asue120b:00-04f3:31c0-touchpad}"
touchpad_state_file="${XDG_RUNTIME_DIR:-$HOME/.cache}/quickshell-touchpad-enabled"
caps_led="${CAPS_LOCK_LED:-}"
upower_kbd_service="org.freedesktop.UPower"
upower_kbd_path="/org/freedesktop/UPower/KbdBacklight"
upower_kbd_interface="org.freedesktop.UPower.KbdBacklight"

ipc() {
	quickshell ipc -c "$config_name" call osd "$@" >/dev/null 2>&1 || true
}

brightness_percent() {
	"$script_root/status/brightness.sh" "$brightness_device" | jq -r '.percent // 0'
}

sink_volume() {
	pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F'/' 'NR==1 { gsub(/[ %]/, "", $2); print $2 }'
}

sink_muted() {
	pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2 == "yes" ? "true" : "false"}'
}

source_muted() {
	pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2 == "yes" ? "true" : "false"}'
}

set_mic_led() {
	local muted="$1"
	local value=0

	[[ "$muted" == "true" ]] && value=1
	brightnessctl -d "$mic_led_device" set "$value" >/dev/null 2>&1 || true
}

keyboard_percent() {
	local current max
	if current="$(upower_keyboard_get)" && max="$(upower_keyboard_max)" && [[ "$max" =~ ^[0-9]+$ && "$current" =~ ^[0-9]+$ && "$max" -gt 0 ]]; then
		printf '%s\n' "$(((current * 100 + max / 2) / max))"
		return
	fi

	current="$(brightnessctl -d "$keyboard_device" g 2>/dev/null || printf '0')"
	max="$(brightnessctl -d "$keyboard_device" m 2>/dev/null || printf '1')"
	if [[ "$max" =~ ^[0-9]+$ && "$current" =~ ^[0-9]+$ && "$max" -gt 0 ]]; then
		printf '%s\n' "$(((current * 100 + max / 2) / max))"
	else
		printf '0\n'
	fi
}

upower_keyboard_get() {
	gdbus call --system \
		--dest "$upower_kbd_service" \
		--object-path "$upower_kbd_path" \
		--method "$upower_kbd_interface.GetBrightness" 2>/dev/null |
		awk -F'[(), ]+' '{print $2}'
}

upower_keyboard_max() {
	gdbus call --system \
		--dest "$upower_kbd_service" \
		--object-path "$upower_kbd_path" \
		--method "$upower_kbd_interface.GetMaxBrightness" 2>/dev/null |
		awk -F'[(), ]+' '{print $2}'
}

upower_keyboard_set() {
	local value="$1"

	gdbus call --system \
		--dest "$upower_kbd_service" \
		--object-path "$upower_kbd_path" \
		--method "$upower_kbd_interface.SetBrightness" "$value" >/dev/null 2>&1
}

keyboard_change() {
	local delta="$1"
	local current max next

	if current="$(upower_keyboard_get)" && max="$(upower_keyboard_max)" && [[ "$max" =~ ^[0-9]+$ && "$current" =~ ^[0-9]+$ && "$max" -gt 0 ]]; then
		next=$((current + delta))
		((next < 0)) && next=0
		((next > max)) && next=max
		upower_keyboard_set "$next" || return 1
		return 0
	fi

	if ((delta > 0)); then
		brightnessctl -d "$keyboard_device" set "+$delta"
	else
		brightnessctl -d "$keyboard_device" set "$((-delta))-"
	fi
}

caps_enabled() {
	local led state

	if [[ -n "$caps_led" && -r "$caps_led" ]]; then
		read -r state <"$caps_led"
		[[ "$state" == "1" ]] && printf 'true\n' || printf 'false\n'
		return
	fi

	for led in /sys/class/leds/*::capslock/brightness; do
		[[ -r "$led" ]] || continue
		read -r state <"$led"
		if [[ "$state" == "1" ]]; then
			printf 'true\n'
			return
		fi
	done

	printf 'false\n'
}

show_volume() {
	ipc volume "$(sink_volume)" "$(sink_muted)"
}

raise_volume() {
	local step="${1:-2}"
	local current next

	current="$(sink_volume)"
	[[ "$current" =~ ^[0-9]+$ ]] || current=0
	[[ "$step" =~ ^[0-9]+$ ]] || step=2
	next=$((current + step))

	if ((current < 100 && next > 100)); then
		pactl set-sink-volume @DEFAULT_SINK@ 100%
	else
		pactl set-sink-volume @DEFAULT_SINK@ +"$step%"
	fi
}

show_mic() {
	local muted percent
	muted="$(source_muted)"
	set_mic_led "$muted"
	percent=100
	[[ "$muted" == "true" ]] && percent=0
	ipc mic "$percent" "$muted"
}

show_brightness() {
	ipc brightness "$(brightness_percent)"
}

show_keyboard() {
	ipc keyboard "$(keyboard_percent)"
}

camera_enabled() {
	local current
	current="$(brightnessctl -d "$camera_device" g 2>/dev/null || printf '0')"
	[[ "$current" != "0" ]] && printf 'true\n' || printf 'false\n'
}

show_camera() {
	ipc camera "$(camera_enabled)"
}

touchpad_enabled() {
	if [[ -r "$touchpad_state_file" ]]; then
		case "$(cat "$touchpad_state_file")" in
		true | false)
			cat "$touchpad_state_file"
			return
			;;
		esac
	fi

	printf 'true\n'
}

set_touchpad() {
	local enabled="$1"

	[[ "$enabled" == "true" || "$enabled" == "false" ]] || return 1
	[[ "$touchpad_device" =~ ^[a-zA-Z0-9_.:-]+$ ]] || return 1
	hyprctl eval "hl.device({ name = \"$touchpad_device\", enabled = $enabled })" >/dev/null || return 1
	mkdir -p "$(dirname "$touchpad_state_file")"
	printf '%s\n' "$enabled" >"$touchpad_state_file"
}

show_touchpad() {
	ipc touchpad "$(touchpad_enabled)"
}

show_caps() {
	ipc caps "$(caps_enabled)"
}

case "${1:-}" in
volume-up)
	raise_volume "${2:-2}" || exit 1
	show_volume
	;;
volume-down)
	pactl set-sink-volume @DEFAULT_SINK@ -"${2:-2}%" || exit 1
	show_volume
	;;
volume-set)
	pactl set-sink-volume @DEFAULT_SINK@ "${2:-0}%" || exit 1
	show_volume
	;;
volume-mute)
	pactl set-sink-mute @DEFAULT_SINK@ toggle || exit 1
	show_volume
	;;
mic-mute)
	pactl set-source-mute @DEFAULT_SOURCE@ toggle || exit 1
	show_mic
	;;
mic-show)
	show_mic
	;;
brightness-up)
	brightnessctl -d "$brightness_device" set +"${2:-2}%" || exit 1
	show_brightness
	;;
brightness-down)
	brightnessctl -d "$brightness_device" set "${2:-2}%-" || exit 1
	show_brightness
	;;
brightness-set)
	brightnessctl -d "$brightness_device" set "${2:-0}%" || exit 1
	show_brightness
	;;
keyboard-up)
	keyboard_change "${2:-1}" || exit 1
	show_keyboard
	;;
keyboard-down)
	keyboard_change "-${2:-1}" || exit 1
	show_keyboard
	;;
keyboard-toggle)
	if [[ "$(keyboard_percent)" -gt 0 ]]; then
		keyboard_change -100 || exit 1
	else
		keyboard_change 100 || exit 1
	fi
	show_keyboard
	;;
camera-toggle)
	if [[ "$(camera_enabled)" == "true" ]]; then
		brightnessctl -d "$camera_device" set 0 || exit 1
	else
		brightnessctl -d "$camera_device" set 1 || exit 1
	fi
	show_camera
	;;
touchpad-toggle)
	if [[ "$(touchpad_enabled)" == "true" ]]; then
		set_touchpad false || exit 1
	else
		set_touchpad true || exit 1
	fi
	show_touchpad
	;;
caps)
	sleep 0.12
	show_caps
	;;
*)
	printf 'usage: %s {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down|brightness-set|keyboard-up|keyboard-down|keyboard-toggle|camera-toggle|touchpad-toggle|caps} [amount]\n' "$0" >&2
	exit 2
	;;
esac
