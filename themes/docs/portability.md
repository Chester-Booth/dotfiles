# Theme portability

`themectl export THEME` writes a deterministic `.blox-theme` ZIP bundle. It
contains `theme.json`, `preview.svg`, `dependencies.json` and `manifest.json`.
The manifest identifies the bundle and theme schema versions and records every
payload file's byte length and SHA-256 digest.

The wallpaper remains an external path by default. `--include-wallpaper` adds
one regular wallpaper file under `wallpaper/`; installed fonts, GTK themes,
icon themes and cursor sources are dependency notes only.

`themectl import FILE` accepts either a bundle or loose theme JSON. Before any
library write, it enforces these boundaries:

- at most 8 archive members, 48 MiB per member and 64 MiB extracted in total;
- relative POSIX paths without traversal, duplicate names or backslashes;
- regular files only, with links, devices and directories rejected;
- an exact manifest file list with matching sizes and SHA-256 digests;
- a supported bundle and theme schema followed by strict theme validation.

An included wallpaper is copied to `$XDG_DATA_HOME/blox/wallpapers/THEME_ID/`
and its source path is updated in the imported theme. The imported theme JSON is
stored under `$XDG_DATA_HOME/blox/themes/`; both paths default to
`~/.local/share/blox/`. Missing local dependencies are warnings.
Import never changes the active runtime generation; Apply remains separate.
Existing theme IDs and export destinations are never overwritten. The picker
exports the saved source only, so Import and Export are disabled while the
editor has unsaved changes. Bundle SVG previews and dependency notes are never
trusted as UI content; the picker renders only the strictly validated theme.
Repository source ledgers are documentation and are not bundled. Showcase WebP
files embed their source and licence XMP, which remains part of the wallpaper
when a bundle includes it.

Built-in themes are stored as JSON plus WebP application data, not as
`.blox-theme` archives. The archive format only crosses the import/export
boundary. Source ledgers stay in the repository and do not form part of an
imported user theme.
