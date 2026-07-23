# Broader unprivileged targets

Phase 7 gives every supported target an isolated generated file. Normal Apply
never edits generated state in place and never requests elevation.

| Target | Generated file | Integration and reload policy |
| --- | --- | --- |
| Hyprland | `hyprland/theme.lua` | `appearance.lua` conditionally loads the managed link; `hyprctl reload` is automatic. |
| Hyprlock | `hyprlock/theme.conf` | `hyprlock.conf` sources the managed link; the next lock process reads it. |
| btop | `btop/theme.theme` | `btop.conf` names the managed theme; restart btop. |
| Micro | `micro/blox-theme.micro` | A managed colourscheme link is installed; restart Micro. |
| Glow | `glow/style.json` | `GLOW_STYLE` points to the managed JSON style under `XDG_CONFIG_HOME`; the next invocation reads it. |
| Code/Cursor | `code/settings.json`, `cursor-editor/settings.json` | Generated fragments contain only owned editor font and workbench colour keys. Merge them into user settings and run **Reload Window**; unrelated settings are never rewritten. |
| Stylus | `stylus/blox-system.user.css` | Import or refresh manually in Stylus. Website font replacement is intentionally absent. |
| Powerlevel10k | `powerlevel10k/theme.zsh` | `.p10k.zsh` conditionally sources the managed fragment; new shells read it. |

Reset removes the target from the active generation. Hyprlock, btop, Micro and
Glow keep their tracked integration valid through an isolated canonical
fallback; optional Hyprland and Powerlevel10k loaders are removed. Applications
with no safe live API report the required restart or manual action through CLI
JSON warnings, which the picker displays. Settings previously merged into Code
or Cursor, and a Stylus style previously imported by the user, require manual
reversion. Wofi and Qt/Kvantum are deliberately unsupported.
