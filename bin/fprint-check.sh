#!/bin/bash

if fprintd-list "$USER" 2>/dev/null | grep -q "has no fingers enrolled"; then
	action=$(notify-send \
		--action=reenroll=Re-enroll \
		"Fingerprint" \
		"Enrollments wiped. Click to re-enroll.")

	if [ "$action" = "reenroll" ]; then
		~/.local/bin/fprint-reenroll.sh
	fi
fi
