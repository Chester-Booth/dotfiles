# Blox Quickshell

Quickshell configuration for the left rail and Eww-style overlays.

This config is independent from the old Waybar setup. Runtime helper scripts now
live under neutral backend directories in `scripts/`, while the old top-level
Waybar and Eww configs are left stale outside this live path.

Run with:

```sh
quickshell -c blox
```

Layout:

- `shell.qml` - Quickshell entrypoint.
- `modules/` - top-level shell surfaces, including the left rail and Eww-style todo/calendar overlays.
- `shared/` - theme and reusable UI pieces.
- `services/` - polling/process wrappers for script-backed state.
- `popouts/` - click-open panel surfaces.
- `scripts/status/` - JSON status producers for the rail and popouts.
- `scripts/{calendar,display,gpu,network,power,todo,update,workspaces}/` - action and domain backends.
- `scripts/overlays/` - background todo/calendar overlay helpers.
- `scripts/contracts/status.json` - expected JSON contracts for status-producing scripts.

Validate script output contracts with:

```sh
~/.config/quickshell/blox/scripts/validate-status.py
```

The contracts keep script changes honest: each producer must emit valid JSON
with the fields and types the QML expects.
