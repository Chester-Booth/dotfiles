#!/bin/bash

state_file="/tmp/waybar-update-notify.state"
critical_threshold=100

count_lines() {
    awk 'NF { count++ } END { print count + 0 }' <<<"$1"
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

repo_output=$(checkupdates 2>&1)
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

aur_output=$(yay -Qua 2>&1)
aur_status=$?
aur_updates=0
aur_failed=0

if (( aur_status == 0 )); then
    aur_updates=$(count_lines "$aur_output")
elif (( aur_status == 1 )) && [[ -z "$aur_output" ]]; then
    aur_updates=0
else
    aur_failed=1
fi

if (( repo_failed || aur_failed )); then
    clear_notification_state
    failed_checks=()

    if (( repo_failed )); then
        failed_checks+=("official repos")
    fi

    if (( aur_failed )); then
        failed_checks+=("AUR")
    fi

    printf -v failed_list '%s, ' "${failed_checks[@]}"
    tooltip="Update check failed: ${failed_list%, }"
    printf '{"alt":"error","class":"error","tooltip":"%s"}\n' "$tooltip"
elif (( repo_updates + aur_updates > critical_threshold )); then
    notify_critical_updates "$((repo_updates + aur_updates))" "$repo_updates" "$aur_updates"
    printf '{"alt":"hundred","class":"hundred","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
elif (( repo_updates + aur_updates > 50 )); then
    clear_notification_state
    printf '{"alt":"fifty","class":"fifty","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
elif (( repo_updates + aur_updates == 0 )); then
    clear_notification_state
    printf '{"alt":"zero","class":"zero","tooltip":"Up to Date!"}\n'
else
    clear_notification_state
    printf '{"alt":"lessfifty","class":"lessfifty","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
fi
