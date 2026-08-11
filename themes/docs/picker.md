# Theme picker integration

Open, inspect or cancel the Quickshell picker with:

```sh
~/.config/quickshell/blox/scripts/theme/picker-ipc.sh open
~/.config/quickshell/blox/scripts/theme/picker-ipc.sh status
~/.config/quickshell/blox/scripts/theme/picker-ipc.sh cancel
```

`generateCurrent` opens simple mode and runs the preferred Matugen adapter for
the active theme's wallpaper. The picker is a movable regular window kept
floating by the tracked Hyprland rule. Its wallpaper chooser is window-modal,
centred and transient to the picker so it stays on the same workspace. The
preview changes only the in-process Quickshell `Theme` singleton, including its
double-buffered wallpaper surface. Save and library actions call the versioned
JSON `themectl` API; Apply is the only picker action that changes external
targets.

The editor uses Quickshell-themed controls throughout. Generated wallpaper
themes are inserted at the top of the library as `UNSAVED` until saved. Font
fields are searchable lists whose rows preview each family in its own typeface.
Semantic and target colours open the themed saturation, value and hue picker;
raw hex remains available as a secondary precision input.

Advanced mode exposes one named desktop-widget profile: minimal, compact or
comfortable. The preset owns overlay opacity, spacing, radius and type size;
those resolved values are intentionally not edited independently.

Existing themes are replaced only with the source SHA-256 returned by
`themectl list --json`. Rename changes `name`, never `id`. Duplicate requires a
new schema-valid ID. Delete requires both the picker confirmation and CLI
`--yes`; built-in and active themes cannot be deleted. Built-ins can be
duplicated into the XDG user library and edited there.

Tracked XDG desktop launchers provide Open and Create actions through the
Quickshell launcher and other application menus.
