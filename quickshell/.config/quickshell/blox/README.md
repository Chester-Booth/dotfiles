# Blox Quickshell

Initial Quickshell migration target for the Waybar rail.

This config is intentionally separate from the existing Waybar setup. The
current Waybar and Eww scripts were copied into `scripts/` so new shell modules
can wrap them without changing the old bar.

Run with:

```sh
quickshell -c blox
```

Layout:

- `shell.qml` - Quickshell entrypoint.
- `modules/` - top-level shell surfaces, starting with the left rail.
- `shared/` - theme and reusable UI pieces.
- `services/` - polling/process wrappers for script-backed state.
- `popouts/` - click-open panel surfaces.
- `scripts/waybar/` - cloned Waybar scripts.
- `scripts/eww/` - cloned Eww scripts.

The next migration step is to replace tooltip-shaped script output with stable
JSON status/action contracts for the popout panels.
