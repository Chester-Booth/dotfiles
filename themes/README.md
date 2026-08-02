# Blox themes

Theme JSON under `themes/` is editable source. Generated files under
`$XDG_STATE_HOME/blox-theme/` are disposable and must not be edited. Validation,
preview, diff, and in-memory render operations do not alter live state.

Install the preferred schema validator with:

```sh
python -m pip install -r themes/requirements.txt
```

The CLI includes a strict bootstrap validator so repository checks remain
available before that optional Python package is installed.

## Commands

```text
themectl list [--json]
themectl show THEME [--json]
themectl validate THEME [--json]
themectl render THEME [--output DIR] [--json]
themectl preview THEME [--json]
themectl diff THEME [--json]
themectl doctor [--json]
themectl apply THEME [--targets LIST] [--json]
themectl reconcile [--targets LIST] [--json]
themectl rollback [GENERATION] [--json]
themectl reset-target TARGET [--json]
themectl setup gtk --yes [--json]
themectl setup cursor --yes [--json]
themectl generate WALLPAPER [--backend matugen|pywal] [--mode dark|light] [--json]
themectl save THEME_JSON [--json]
themectl duplicate THEME NEW_ID [--name NAME] [--json]
themectl rename THEME DISPLAY_NAME [--json]
themectl delete THEME --yes [--json]
themectl import FILE [--json]
themectl export THEME [--output FILE] [--include-wallpaper] [--json]
```

Without `--output`, `render` operates in memory. `preview`, `diff`, and `doctor`
are read-only. An explicit render output is never treated as live state.

`apply` renders a complete candidate, verifies it, atomically switches the
`current` symlink, and then reloads requested targets. A reload failure leaves
valid generated files active, returns exit code 7, and prints a manual recovery
command. Unselected or disabled target files are carried forward byte for byte.
The current generation and five previous generations are retained.

`reconcile` verifies the active manifest and repeats runtime reload actions
without rendering. `rollback` activates a retained generation. `reset-target`
creates a new generation without that target and restores its non-generated
fallback. All live-state mutating commands use a non-blocking application lock.

The `widgets` target renders a named Quickshell overlay profile. Resolved
geometry remains preset-owned, and reset restores the canonical minimal
profile.

## Palette generation

`generate` is read-only and defaults to Matugen. It runs Matugen or pywal with
an isolated home, cache, configuration, and data directory; it cannot change
the live wallpaper, terminal, GTK settings, or generator cache. Wallust is
intentionally disabled. The result contains an editable theme, all required
contrast measurements, the backend and version, algorithm options, mapping
version, and source wallpaper digest. Generation never saves or applies a
theme.

Matugen supports `--scheme`, `--contrast`, and `--source-colour-index`. Pywal
supports `--saturate`. Both support `--mode`. Backend-specific options are
rejected when used with the other backend.

Extract or edit `.data.theme`, then pass the JSON file (or `-` for stdin) to
`save`. Saving validates the complete theme, writes it under `themes/themes/`,
and refuses to overwrite an existing source. A saved generated theme behaves
like any hand-authored source theme and still requires an explicit `apply`.
Use `save --replace --expect-sha256 DIGEST` for an existing source; the digest
from `list --json` prevents stale picker sessions overwriting newer edits.

## Portability

`export` creates a versioned `.blox-theme` bundle containing strict theme JSON,
an SVG preview, dependency notes and a digest manifest. Wallpapers remain path
references unless `--include-wallpaper` is supplied. Fonts and third-party GTK,
icon and cursor themes are recorded as dependencies and are never bundled.

`import` accepts strict loose JSON or a bundle created by `themectl`. Bundles
are checked for safe relative paths, regular files, bounded sizes and file
counts, and matching manifest digests before the theme library is changed.
Imported wallpapers are placed under `themes/wallpapers/`. Import reports
missing dependencies as warnings and never previews or applies the theme.
Unsupported schema versions fail before any files are written; schema migration
hooks are isolated at the import boundary for future versions.

## Picker

The full picker runs inside Quickshell and opens through the `themePicker` IPC
target. It lists and searches themes, previews semantic colours and fonts,
reports target and dependency impact, generates wallpaper palettes, edits
semantic and target-specific values, and exposes save, apply, duplicate,
display-name rename, delete and revert actions. Temporary preview affects only
Quickshell until Apply. Dirty navigation and deletion require separate
confirmation; closing or cancelling restores the active Quickshell theme.

Vicinae script commands provide Apply Theme, Create Theme from Current
Wallpaper and Open Theme Picker actions. See [picker integration](docs/picker.md).

## GTK target

Generated GTK mode layers semantic GTK 3 and GTK 4 CSS over the selected base
theme and supplies generated settings for the interface font, icon theme and
dark preference. Installed mode changes settings but emits no generated CSS.

Run `themectl setup gtk --yes` once if existing GTK user styles need migration.
Setup records valid stylesheet symlinks as reset fallbacks, ignores broken
legacy targets, and refuses regular user stylesheets. GTK applications must be
restarted after changes. Libadwaita support is best-effort user CSS rather than
full base-theme support; see [GTK compatibility](docs/gtk-compatibility.md).

## Cursor target

Generated mode rebuilds the pinned Bibata Modern Classic source with the
selected handedness, sizes and cursor colours. Run `themectl setup cursor
--yes` once to install its user-local Clickgen/cbmp toolchain and record the
pre-theme cursor selection. Builds are content-addressed and validated before
the stable `blox-generated` icon link changes; installed mode bypasses the
toolchain and cache. GTK/GSettings and Hyprland are updated together. Existing
applications may retain old cursor assets until restart. See [cursor
generation](docs/cursor-generation.md) for source, licence, checksum, setup and
cache details.

Every JSON response has `api_version`, `command`, `ok`, `status`, `data`,
`warnings`, and `errors` fields.

## Exit codes

| Code | Meaning |
| ---: | --- |
| 0 | success, including non-blocking warnings |
| 2 | command-line usage error |
| 3 | invalid JSON, schema, colour, or contrast |
| 4 | missing theme or required dependency |
| 5 | render failure |
| 6 | apply or source-save failure |
| 7 | reload warning |
| 8 | application lock contention |

Run `make validate-themes` for schema fixtures, golden render checks, and
determinism coverage. After an intended change to the canonical `blox-panel`
theme or its renderer, run `make update-theme-golden` to accept the new output.
