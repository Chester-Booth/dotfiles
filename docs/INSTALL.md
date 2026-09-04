# Install Guide

These dotfiles are intended for the current Hyprland and Quickshell desktop.
Top-level `waybar/`, `eww/`, and `wofi/` are stale backups and should stay
untracked.

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
gcalcli pactl nmcli bluetoothctl brightnessctl asusctl hyprshot arch-update qalc sqlite3 wl-copy wl-paste wtype notify-send python-pillow ttf-twemoji
```

The exact package names vary by distro. On Arch-based systems, most are either
repo packages or AUR packages.

The showcase themes use separate distro-packaged font sets. See
[`themes/docs/showcase-fonts.md`](../themes/docs/showcase-fonts.md) for the Arch
and AUR package names and the exact Fontconfig families used by each theme.

## 3. Link Configs

Create or refresh the live links:

```sh
mkdir -p ~/.config/hypr ~/.config/quickshell ~/.local/bin

ln -sfn "$PWD/hyprland/.config/hypr/hyprland.lua" ~/.config/hypr/hyprland.lua
ln -sfn "$PWD/hyprland/.config/hypr/conf.d" ~/.config/hypr/conf.d
ln -sfn "$PWD/hyprland/.config/hypr/workspaces.lua" ~/.config/hypr/workspaces.lua
mkdir -p ~/.config/hypr/generated
ln -sfn "$PWD/hyprland/.config/hypr/generated/hyprsunset.conf" ~/.config/hypr/generated/hyprsunset.conf
ln -sfn "$PWD/quickshell/.config/quickshell/blox" ~/.config/quickshell/blox
ln -sfn "$PWD/bin/battery-low-power" ~/.local/bin/battery-low-power
ln -sfn "$PWD/bin/fprint-check.sh" ~/.local/bin/fprint-check.sh
ln -sfn "$PWD/bin/fprint-reenroll.sh" ~/.local/bin/fprint-reenroll.sh
ln -sfn "$PWD/bin/floating_sudo" ~/.local/bin/floating_sudo
ln -sfn "$PWD/bin/dmenu" ~/.local/bin/dmenu
```

The dmenu client implements `-i`, `-p`, `-l`, `-m`, `-b` and `-f`. With `-f`,
the launcher takes focus before the client finishes reading stdin. Font and
colour flags are no-ops because the active shell theme owns those values.

`floating_sudo` needs Kitty, sudo, Python 3, a graphical session, and
`XDG_RUNTIME_DIR`. It streams approved command output back to the calling
terminal while keeping the approval window open. Check its reject path before
approving a command:

```sh
floating_sudo $'sudo /usr/bin/true\n/usr/bin/true > Test the approval flow > Confirm the wrapper returns success without changing the system\nRisk level: low > The command has no side effects' /usr/bin/true
```

Press Enter to reject it. Run the same command again and enter `y` to test the
approval and output relay paths.

Keep any stale `~/.config/waybar`, `~/.config/eww`, or `~/.config/wofi` links
disconnected unless intentionally booting the old setup.

Link or copy the optional user-level app/config files you want:

```sh
mkdir -p ~/.config/Code/User ~/.config/Thunar ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/xsettingsd ~/.config/environment.d ~/.local/share/flatpak/overrides ~/.local/share/icons/default
ln -sfn "$PWD/applications/.config/mimeapps.list" ~/.config/mimeapps.list
ln -sfn "$PWD/thunar/.config/Thunar/uca.xml" ~/.config/Thunar/uca.xml
ln -sfn "$PWD/code/.config/Code/User/chatLanguageModels.json" ~/.config/Code/User/chatLanguageModels.json
ln -sfn "$PWD/gtk/.config/gtk-3.0/settings.ini" ~/.config/gtk-3.0/settings.ini
ln -sfn "$PWD/gtk/.config/gtk-4.0/settings.ini" ~/.config/gtk-4.0/settings.ini
ln -sfn "$PWD/gtk/home/.gtkrc-2.0" ~/.gtkrc-2.0
ln -sfn "$PWD/xsettingsd/.config/xsettingsd/xsettingsd.conf" ~/.config/xsettingsd/xsettingsd.conf
ln -sfn "$PWD/environment/.config/environment.d/10-hyprland-appearance.conf" ~/.config/environment.d/10-hyprland-appearance.conf
ln -sfn "$PWD/icons/.local/share/icons/default/index.theme" ~/.local/share/icons/default/index.theme
ln -sfn "$PWD/flatpak/.local/share/flatpak/overrides/global" ~/.local/share/flatpak/overrides/global

mkdir -p ~/.docker
ln -sfn "$PWD/docker/home/.docker/daemon.json" ~/.docker/daemon.json
```

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
systemctl --user start quickshell.service
systemctl --user enable --now battery-low-power.timer
systemctl --user enable --now fprint-check.timer
systemctl --user enable --now gcal-update.timer
systemctl --user enable --now gdrive-bisync.timer
systemctl --user enable --now icloud-bisync.timer
systemctl --user enable --now qalc-currency-update.timer
```

Skip timers for services you do not use. Hyprland starts `quickshell.service`
after it imports the Wayland session environment, so do not enable this unit
under `default.target`.

## 6. Boot Themes

Copy the SDDM theme, link the system GRUB theme path back to the repo, copy the
bootable GRUB theme into `/boot`, install the GRUB drop-ins/scripts, and
regenerate GRUB:

```sh
sudo bin/install-boot-themes
```

See [BOOT_THEMES.md](BOOT_THEMES.md) for the SDDM base-theme license note and
why the GRUB theme is copied rather than symlinked on this machine.

## 7. Machine Config

Machine-level config that is not part of a package-specific tree is mirrored
under `system-etc/etc`. Review it before applying on another host:

```sh
sudo cp -a system-etc/etc/. /etc/
sudo systemctl daemon-reload
sudo systemctl enable --now gpu-eco-boot.service
```

The NVIDIA, SDDM, fingerprint, PAM, udev, and logind files in this tree are
machine-specific.

## 8. Validate

Run the repo checks:

```sh
make check
```

Run the machine-level doctor:

```sh
make doctor
```

`make check` validates source files and contracts. `make doctor` also checks live
links, ignored private env files, stale Waybar/Eww/Wofi boundaries, Hyprland,
Quickshell IPC, and user timers.

## 9. Start Or Reload

Reload Hyprland after link changes:

```sh
hyprctl reload
hyprctl configerrors
```

Restart Quickshell with the live config:

```sh
systemctl --user restart quickshell.service
```

If repeated start failures hit the service rate limit, inspect the log, clear
the failed state, then start it again:

```sh
journalctl --user -u quickshell.service -b
systemctl --user reset-failed quickshell.service
systemctl --user restart quickshell.service
```

To stop automatic restarts while fixing a broken config:

```sh
systemctl --user stop quickshell.service
```

## 10. Laptop Power Button

Hyprland binds a short power-button press to the Quickshell power overlay. If
systemd handles the key before Hyprland sees it, add this machine-level setting:

```sh
sudo install -d -m 0755 /etc/systemd/logind.conf.d
printf '%s\n' '[Login]' 'HandlePowerKey=ignore' | sudo tee /etc/systemd/logind.conf.d/90-power-key.conf
```

Then restart `systemd-logind` or reboot. Holding the physical button still uses
the firmware force-off path.
