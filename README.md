# Dotfiles

Personal desktop dotfiles for Hyprland, Quickshell, shell tools, systemd user
timers, and app configuration.

## Live Desktop

- `hyprland/.config/hypr/hyprland.conf` is the Hyprland entrypoint and sources
  `hyprland/.config/hypr/conf.d/*.conf`.
- `quickshell/.config/quickshell/blox` is the live bar/overlay setup.
- Top-level `waybar/`, `eww/`, and `wofi/` are intentionally stale and ignored
  so they can be revived later without affecting the live desktop.

## Private Env

The real Quickshell env file is ignored:

```sh
~/.config/quickshell/blox/env
```

Use this tracked template:

```sh
cp quickshell/.config/quickshell/blox/env.example ~/.config/quickshell/blox/env
```

Currently supported:

- `EXPENSES_API_BASE_URL` - optional base URL used by the generated todo refresh
  script. Leave unset to disable expenses-generated todo files.

## Checks

Run the non-mutating checks:

```sh
make check
```

Run the machine-level doctor:

```sh
make doctor
```

Useful focused targets:

```sh
make validate-status
make systemd-verify
make format
```

`make check` validates Quickshell JSON script contracts, Python syntax, systemd
unit files, and Git whitespace. `make doctor` additionally checks live links,
ignored private env files, stale Waybar/Eww/Wofi boundaries, runtime tools,
Hyprland, Quickshell IPC, and user timers. `make format` runs mutating
formatters.

## Install

See [docs/INSTALL.md](docs/INSTALL.md) for the full bootstrap guide.
