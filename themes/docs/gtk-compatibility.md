# GTK compatibility

Validated on 1 July 2026 with GTK 3.24.52, GTK 4.22.4 and Libadwaita
1.9.2.

## Supported path

- GTK 3 and GTK 4 load user CSS after the selected base theme. Generated CSS
  can therefore override Graphite colours while retaining its layout and
  assets.
- The user CSS layer still loads when `GTK_THEME` forces a base theme. The
  environment variable nevertheless prevents installed-theme selection from
  working reliably, so fixed repository and portal overrides were removed.
- GTK settings and font choices are exposed through generated `settings.ini`
  files and matching `gsettings` values. Existing applications generally need
  to restart.
- Installed mode switches settings but deliberately emits no generated CSS.
- GTK 4's generic `.background` class also marks popovers. Generated CSS
  therefore colours `window` directly and leaves the outer popover node
  transparent; `popover > contents` still receives the generated surface
  colour.

## Libadwaita boundary

Libadwaita selected its own `Adwaita-empty` base during the unforced probe. It
accepted ordinary user CSS for tested controls, but does not support
`gtk-application-prefer-dark-theme` and may ignore base-theme or higher
specificity widget overrides. It is therefore reported as partial user-CSS
support, not full Graphite theming.

## Upstream Graphite warning

The installed Graphite GTK 4 stylesheet reports an existing `Not a valid
image` parser warning near line 7108. The generated override stylesheets parse
without errors in both GTK versions. This upstream warning does not block the
generated colour layer.
