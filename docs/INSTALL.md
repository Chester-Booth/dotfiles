# Install Guide

These dotfiles are intended for the current Hyprland and Quickshell desktop.
Top-level `waybar/` and `eww/` are stale backups and should stay untracked.

## 1. Clone

```sh
git clone <repo-url> ~/Code/personal/dotfiles
cd ~/Code/personal/dotfiles
```

## 2. Install Tools

Core checks expect these commands:

```sh
git make python3 jq ripgrep qmlformat shfmt shellcheck quickshell hyprctl systemd
```

Runtime helpers used by the desktop include:

```sh
gcalcli pactl nmcli bluetoothctl brightnessctl swaync-client swayosd-client asusctl hyprshot
```

The exact package names vary by distro. On Arch-based systems, most are either
repo packages or AUR packages.

## 3. Link Configs

Create or refresh the live links:

```sh
mkdir -p ~/.config/hypr ~/.config/quickshell ~/.local/bin

ln -sfn "$PWD/hyprland/.config/hypr/hyprland.conf" ~/.config/hypr/hyprland.conf
ln -sfn "$PWD/hyprland/.config/hypr/conf.d" ~/.config/hypr/conf.d
ln -sfn "$PWD/quickshell/.config/quickshell/blox" ~/.config/quickshell/blox
ln -sfn "$PWD/bin/battery-low-power" ~/.local/bin/battery-low-power
```

Keep any stale `~/.config/waybar` or Eww links disconnected unless intentionally
booting the old setup.

## 4. Private Env

Create the ignored Quickshell env file from the tracked example:

```sh
cp quickshell/.config/quickshell/blox/env.example ~/.config/quickshell/blox/env
```

`EXPENSES_API_BASE_URL` is optional. Leave it empty to disable
expenses-generated todo files.

## 5. User Services

Link or install the user units, then enable the timers you want:

```sh
mkdir -p ~/.config/systemd/user
ln -sfn "$PWD/systemd"/*.service "$PWD/systemd"/*.timer ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now battery-low-power.timer
systemctl --user enable --now fprint-check.timer
systemctl --user enable --now gcal-update.timer
systemctl --user enable --now gdrive-bisync.timer
systemctl --user enable --now icloud-bisync.timer
```

Skip timers for services you do not use.

## 6. Validate

Run the repo checks:

```sh
make check
```

Run the machine-level doctor:

```sh
make doctor
```

`make check` validates source files and contracts. `make doctor` also checks live
links, ignored private env files, stale Waybar/Eww boundaries, Hyprland,
Quickshell IPC, and user timers.

## 7. Start Or Reload

Reload Hyprland after link changes:

```sh
hyprctl reload
hyprctl configerrors
```

Start Quickshell with the live config:

```sh
quickshell -p ~/.config/quickshell/blox
```
