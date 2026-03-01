#!/bin/bash

# get official repo updates
repo_updates=$(checkupdates 2>/dev/null | wc -l)

# get AUR updates
aur_updates=$(yay -Qua 2>/dev/null | wc -l)

# output JSON for Waybar
if (( repo_updates + aur_updates > 100 )); then
    printf '{"alt":"hundred","class":"hundred","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
elif (( repo_updates + aur_updates > 50 )); then
    printf '{"alt":"fifty","class":"fifty","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
elif (( repo_updates + aur_updates == 0 )); then
    printf '{"alt":"zero","class":"zero","tooltip":"Up to Date!"}\n'
else
    printf '{"alt":"lessfifty","class":"lessfifty","tooltip":"%d repo updates, %d AUR updates"}\n' "$repo_updates" "$aur_updates"
fi


