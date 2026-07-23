# Cursor generation

Generated cursors use the GPL-3.0-only Bibata Cursor SVG/config source at tag
`v2.0.7` and commit `35ccfe209a808e40d6c2ca60a46cbe4faf68b690`.
The codeload archive and its SHA-256 digest are pinned in
`themes/cursor/source.json`. The setup process verifies the archive before safe
extraction and retains Bibata's `LICENSE` file with the source.

The renderer uses `cbmp` 1.1.1 to recolour and rasterise SVGs, then Clickgen
`ctgen` 2.2.5 to compile Xcursor files. Install the user-local, pinned
toolchain and source explicitly:

```sh
themes/bin/themectl setup cursor --yes
```

Setup needs Python venv support, Node.js, npm and network access. It installs
under `$XDG_DATA_HOME/blox-theme/cursor-toolchain/`; it never installs system
packages. Apply reports the exact missing command when setup cannot proceed.

Generated themes are cached under `$XDG_STATE_HOME/blox-theme/cursors/` using
a digest of the source/tool versions, style, handedness, sizes and three
colours. A validated cache hit avoids both rasterisation and compilation.
`~/.local/share/icons/blox-generated` is an atomic symlink to the active cache.
Installed cursor mode uses the named installed theme and bypasses this source,
toolchain, cache and link.

GTK/GSettings and Hyprland receive the selected theme and primary size during
apply, reconcile, rollback and reset. Existing processes may retain cursors
until they restart or create new surfaces; the CLI reports this limitation.
