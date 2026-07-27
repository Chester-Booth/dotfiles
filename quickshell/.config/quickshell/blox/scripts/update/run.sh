#!/bin/bash
set -euo pipefail

if ! command -v arch-update >/dev/null; then
	echo "arch-update is required. Install it with: yay -S arch-update" >&2
	exit 127
fi

previous_profile=""
profile_changed=0

restore_profile() {
	if ((profile_changed)) && ! asusctl profile set "$previous_profile"; then
		echo "Warning: failed to restore ASUS profile '$previous_profile'." >&2
	fi
}

trap restore_profile EXIT

if command -v yay >/dev/null &&
	command -v asusctl >/dev/null &&
	[[ -n "$(yay -Qua 2>/dev/null)" ]]; then
	previous_profile=$(asusctl profile get | sed -n 's/^Active profile: //p')

	if [[ -n "$previous_profile" && "${previous_profile,,}" != "performance" ]]; then
		profile_changed=1
		asusctl profile set performance
	fi
fi

arch-update
