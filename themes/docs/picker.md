# Theme picker integration

Open, inspect or cancel the Quickshell picker with:

```sh
quickshell ipc -c blox call themePicker open
quickshell ipc -c blox call themePicker status
quickshell ipc -c blox call themePicker cancel
```

`generateCurrent` opens simple mode and runs the preferred Matugen adapter for
the active theme's wallpaper. The picker is a movable regular window kept
floating by the tracked Hyprland rule. Its wallpaper chooser is window-modal,
centred and transient to the picker so it stays on the same workspace. The
preview changes only the in-process Quickshell `Theme` singleton. Save and
library actions call the versioned JSON
`themectl` API; Apply is the only picker action that changes external targets.

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
`--yes`; the canonical and active themes cannot be deleted.

Vicinae discovers the tracked commands under
`~/.local/share/vicinae/scripts/`. They use documented script-command
directives and shell-free Quickshell or `themectl` argument calls:

- Apply Theme accepts a stable theme ID.
- Create Theme from Current Wallpaper opens generation in the picker.
- Open Theme Picker opens the full editor.

Vicinae periodically rescans its script directories. Its built-in Reload
Script Directories command can force immediate discovery. Tracked XDG desktop
launchers provide Open and Create commands through Vicinae's application index
as a fallback for releases whose script scanner does not follow managed paths.
