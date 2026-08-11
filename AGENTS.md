## Checks

Run the repo checks before finishing substantive changes:

```sh
make check
```

Useful narrower targets:

```sh
make format
make doctor
make validate-status
make systemd-verify
```

`make doctor` is a non-mutating machine-level check for live symlinks, ignored
private env files, runtime tools, Hyprland, Quickshell IPC, and user timers. 

## JSON Script Contracts

Status-producing scripts must emit valid JSON matching `quickshell/.config/quickshell/blox/scripts/contracts/status.json`.
If a script changes fields or types, update the contract and run:

```sh
quickshell/.config/quickshell/blox/scripts/validate-status.py
```

Do not rely on tooltip string parsing for fields the QML needs.

## Editing Notes

- Edit theme sources under `themes/` and stable target integration files only;
  never edit generated files under `$XDG_STATE_HOME/blox-theme/`.

- When Picking Icons, use Phosphor icons's online full list, and download as needed.
