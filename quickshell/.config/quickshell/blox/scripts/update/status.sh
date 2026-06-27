#!/bin/bash

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/update"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/update"
runtime_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/quickshell"
state_file="$state_dir/notified-count"
cache_file="$cache_dir/status.json"
lock_file="$runtime_dir/update-check.lock"
cache_ttl=15
critical_threshold=100
retry_delay=2
retry_attempts=3

mkdir -p "$state_dir" "$cache_dir" "$runtime_dir"

cache_is_fresh() {
	local now mtime

	[[ -s "$cache_file" ]] || return 1
	now=$(date +%s)
	mtime=$(stat -c %Y "$cache_file" 2>/dev/null) || return 1

	((now - mtime <= cache_ttl))
}

write_cache() {
	local tmp_file

	tmp_file="${cache_file}.$$"
	printf '%s\n' "$1" >"$tmp_file"
	mv "$tmp_file" "$cache_file"
}

emit_json() {
	write_cache "$1"
	printf '%s\n' "$1"
	exit 0
}

exec 9>"$lock_file"
if flock -w 20 9; then
	if cache_is_fresh; then
		cat "$cache_file"
		exit 0
	fi
elif [[ -s "$cache_file" ]]; then
	cat "$cache_file"
	exit 0
fi

count_lines() {
	awk 'NF { count++ } END { print count + 0 }' <<<"$1"
}

run_checkupdates() {
	local attempt output status

	for ((attempt = 1; attempt <= retry_attempts; attempt++)); do
		output=$(timeout 45s checkupdates 2>&1)
		status=$?

		if ((status == 0 || status == 2)); then
			printf '%s' "$output"
			return "$status"
		fi

		if ((attempt < retry_attempts)); then
			sleep "$retry_delay"
		fi
	done

	printf '%s' "$output"
	return "$status"
}

run_aur_check() {
	local attempt output status

	for ((attempt = 1; attempt <= retry_attempts; attempt++)); do
		output=$(timeout 45s yay -Qua 2>&1)
		status=$?

		if ((status == 0)) || { ((status == 1)) && [[ -z "$output" ]]; }; then
			printf '%s' "$output"
			return "$status"
		fi

		if ((attempt < retry_attempts)); then
			sleep "$retry_delay"
		fi
	done

	printf '%s' "$output"
	return "$status"
}

notify_critical_updates() {
	local total_updates=$1
	local repo_count=$2
	local aur_count=$3
	local previous_total=""

	if [[ -f "$state_file" ]]; then
		previous_total=$(<"$state_file")
	fi

	if [[ "$previous_total" != "$total_updates" ]]; then
		notify-send -u normal -e "Updates Pending" \
			"$total_updates updates available ($repo_count repo, $aur_count AUR)"
		printf '%s\n' "$total_updates" >"$state_file"
	fi
}

clear_notification_state() {
	rm -f "$state_file"
}

repo_output=$(run_checkupdates)
repo_status=$?
repo_updates=0
repo_failed=0

case "$repo_status" in
0)
	repo_updates=$(count_lines "$repo_output")
	;;
2)
	repo_updates=0
	;;
*)
	repo_failed=1
	;;
esac

aur_output=$(run_aur_check)
aur_status=$?
aur_updates=0
aur_failed=0

if ((aur_status == 0)); then
	aur_updates=$(count_lines "$aur_output")
elif ((aur_status == 1)) && [[ -z "$aur_output" ]]; then
	aur_updates=0
else
	aur_failed=1
fi

if ((repo_failed || aur_failed)); then
	clear_notification_state
	failed_checks=()

	if ((repo_failed)); then
		failed_checks+=("official repos")
	fi

	if ((aur_failed)); then
		failed_checks+=("AUR")
	fi

	printf -v failed_list '%s, ' "${failed_checks[@]}"
	tooltip="Update check failed: ${failed_list%, }"
	emit_json "$(printf '{"alt":"error","class":"error","tooltip":"%s"}' "$tooltip")"
elif ((repo_updates + aur_updates > critical_threshold)); then
	notify_critical_updates "$((repo_updates + aur_updates))" "$repo_updates" "$aur_updates"
	emit_json "$(printf '{"alt":"hundred","class":"hundred","tooltip":"%d repo updates, %d AUR updates"}' "$repo_updates" "$aur_updates")"
elif ((repo_updates + aur_updates > 50)); then
	clear_notification_state
	emit_json "$(printf '{"alt":"fifty","class":"fifty","tooltip":"%d repo updates, %d AUR updates"}' "$repo_updates" "$aur_updates")"
elif ((repo_updates + aur_updates == 0)); then
	clear_notification_state
	emit_json '{"alt":"zero","class":"zero","tooltip":"Up to Date!"}'
else
	clear_notification_state
	emit_json "$(printf '{"alt":"lessfifty","class":"lessfifty","tooltip":"%d repo updates, %d AUR updates"}' "$repo_updates" "$aur_updates")"
fi
