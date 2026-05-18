#!/bin/bash
set -e

# update official repos
echo "=== Updating official repos ==="
sudo pacman -Syu

# show number of AUR updates
aur_count=$(yay -Qua | wc -l)
if [ "$aur_count" -gt 0 ]; then
    echo "=== AUR updates available: $aur_count ==="
    echo "Listing AUR packages..."
    yay -Qua
    echo "Press enter to install them or ctrl+c to skip"
    read
    current_profile=$(asusctl profile get | sed -n 's/^Active profile: //p')
    asusctl profile set performance
    yay -Syu
    asusctl profile set "$current_profile"
else
    echo "No AUR updates"
fi