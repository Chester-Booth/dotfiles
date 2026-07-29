from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import RENDERER_VERSION


EXIT_OK = 0
EXIT_USAGE = 2
EXIT_VALIDATION = 3
EXIT_DEPENDENCY = 4
EXIT_RENDER = 5
EXIT_APPLY = 6
EXIT_RELOAD_WARNING = 7
EXIT_LOCKED = 8

IMPLEMENTED_TARGETS = ("quickshell", "vicinae", "widgets", "kitty", "wallpaper", "gtk", "cursor", "hyprland", "hyprlock", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "obsidian", "powerlevel10k")
DEFERRED_TARGETS = {}
TARGET_LIMITATIONS = {
    "hyprland": "Hyprtoolkit apps must be restarted after Apply",
    "hyprlock": "Hyprlock changes apply when the next lock process starts",
    "btop": "btop must be restarted after Apply",
    "micro": "Micro must be restarted after Apply",
    "code": "Code theme installs and applies automatically; use Reload Window for existing windows",
    "cursor_editor": "Cursor settings apply automatically; use Reload Window for existing windows",
    "stylus": "Stylus requires manual import or refresh of the generated UserCSS",
    "obsidian": "Obsidian requires Minimal, Style Settings, and manual import of the generated settings JSON",
    "powerlevel10k": "Powerlevel10k changes apply to new shells",
}

# Logical regions are deliberately orientation-independent: ``start`` is the
# top of a vertical bar and the left of a horizontal one.  Keeping the complete
# registry in rendered documents gives the shell and picker one stable model,
# while themes written before bar customisation continue to receive defaults.
DEFAULT_BAR_ITEMS = (
    {"id": "power", "enabled": True, "region": "start", "order": 0},
    {"id": "notes", "enabled": True, "region": "start", "order": 1},
    {"id": "workspaces", "enabled": True, "region": "start", "order": 2},
    {"id": "clock", "enabled": True, "region": "centre", "order": 0},
    {"id": "battery", "enabled": True, "region": "end", "order": 0, "display": "toggle"},
    {"id": "tray", "enabled": True, "region": "end", "order": 1},
    {"id": "notifications", "enabled": True, "region": "end", "order": 2},
    {"id": "wifi", "enabled": True, "region": "end", "order": 3},
    {"id": "sound", "enabled": True, "region": "end", "order": 4},
    {"id": "privacy", "enabled": True, "region": "hidden", "order": 0},
    {"id": "awake", "enabled": True, "region": "hidden", "order": 1},
    {"id": "display", "enabled": True, "region": "hidden", "order": 2},
    {"id": "bt", "enabled": True, "region": "hidden", "order": 3},
    {"id": "updates", "enabled": True, "region": "hidden", "order": 4},
    {"id": "fan", "enabled": True, "region": "hidden", "order": 5, "visibility": "normal"},
    {"id": "gpu", "enabled": True, "region": "hidden", "order": 6, "visibility": "normal"},
    {"id": "application-tray", "enabled": True, "region": "hidden", "order": 7},
    {"id": "touchpad", "enabled": True, "region": "hidden", "order": 8, "visibility": "normal"},
)


def resolved_bar_items(bar: dict[str, Any] | None) -> list[dict[str, Any]]:
    """Return a complete, ordered bar registry with optional theme overrides."""
    source = (bar or {}).get("items", [])
    overrides = {item["id"]: item for item in source}
    # Prior to the movable drawer toggle, ``tray`` denoted the freedesktop
    # application tray. A complete old registry never contains the new id, so
    # migrate that override while giving the new toggle its normal placement.
    if "tray" in overrides and "application-tray" not in overrides:
        overrides["application-tray"] = {**overrides.pop("tray"), "id": "application-tray"}
    items = [{**default, **overrides.get(default["id"], {})} for default in DEFAULT_BAR_ITEMS]
    application_tray = next(item for item in items if item["id"] == "application-tray")
    application_tray["region"] = "hidden"
    hidden = sorted(
        (item for item in items if item["region"] == "hidden" and item["id"] != "application-tray"),
        key=lambda item: item["order"],
    )
    tray = next(item for item in items if item["id"] == "tray")
    if tray["region"] == "start":
        tray_opens_forward = True
    elif tray["region"] == "centre":
        centre = sorted(
            (item for item in items if item["region"] == "centre"),
            key=lambda item: item["order"],
        )
        tray_opens_forward = bool(centre) and centre[-1]["id"] == "tray"
    else:
        tray_opens_forward = False
    hidden.insert(len(hidden) if tray_opens_forward else 0, application_tray)
    for order, item in enumerate(hidden):
        item["order"] = order
    return items


@dataclass
class CheckResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def repository_root() -> Path:
    return Path(__file__).resolve().parents[3]


def themes_dir() -> Path:
    return repository_root() / "themes"


def state_dir() -> Path:
    root = os.environ.get("XDG_STATE_HOME")
    return Path(root).expanduser() / "blox-theme" if root else Path.home() / ".local/state/blox-theme"


def canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def theme_path(reference: str) -> Path:
    candidate = Path(reference).expanduser()
    if candidate.is_file() or candidate.suffix == ".json" or "/" in reference:
        return candidate
    return themes_dir() / "themes" / f"{reference}.json"


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_theme(reference: str) -> tuple[Path, dict[str, Any]]:
    path = theme_path(reference)
    if not path.is_file():
        raise FileNotFoundError(f"theme not found: {reference}")
    data = load_json(path)
    if not isinstance(data, dict):
        raise ValueError("theme root must be a JSON object")
    return path, data


def list_themes() -> list[dict[str, Any]]:
    entries = []
    for path in sorted((themes_dir() / "themes").glob("*.json")):
        try:
            data = load_json(path)
            entries.append(
                {
                    "id": data.get("id", path.stem),
                    "name": data.get("name", path.stem),
                    "variant": data.get("variant"),
                    "path": str(path),
                    "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "preview": {
                        "colours": data.get("colours", {}),
                        "wallpaper": data.get("wallpaper", {}).get("path", ""),
                        "fonts": {
                            role: data.get("fonts", {}).get(role, "")
                            for role in ("ui", "mono", "panel")
                        },
                        "bar": {
                            "position": data.get("shell", {}).get("bar", {}).get("position", "left"),
                            "items": resolved_bar_items(data.get("shell", {}).get("bar")),
                        },
                    },
                }
            )
        except (OSError, json.JSONDecodeError):
            entries.append({"id": path.stem, "name": path.stem, "variant": None, "path": str(path), "invalid": True})
    return entries


def _resolve_ref(root: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValueError(f"unsupported schema reference: {reference}")
    value: Any = root
    for part in reference[2:].split("/"):
        value = value[part.replace("~1", "/").replace("~0", "~")]
    return value


def _basic_schema_errors(instance: Any, schema: dict[str, Any], root: dict[str, Any], path: str = "$") -> list[str]:
    if "$ref" in schema:
        return _basic_schema_errors(instance, _resolve_ref(root, schema["$ref"]), root, path)
    errors: list[str] = []
    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: must equal {schema['const']!r}")
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: must be one of {schema['enum']}")
    expected = schema.get("type")
    type_ok = {
        "object": isinstance(instance, dict),
        "array": isinstance(instance, list),
        "string": isinstance(instance, str),
        "boolean": isinstance(instance, bool),
        "integer": isinstance(instance, int) and not isinstance(instance, bool),
        "number": isinstance(instance, (int, float)) and not isinstance(instance, bool),
    }.get(expected, True)
    if expected and not type_ok:
        return [f"{path}: expected {expected}"]
    if isinstance(instance, dict):
        properties = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in instance:
                errors.append(f"{path}: missing required property {key!r}")
        if schema.get("additionalProperties") is False:
            for key in instance.keys() - properties.keys():
                errors.append(f"{path}: unknown property {key!r}")
        for key, value in instance.items():
            if key in properties:
                errors.extend(_basic_schema_errors(value, properties[key], root, f"{path}.{key}"))
    elif isinstance(instance, list):
        if len(instance) < schema.get("minItems", 0):
            errors.append(f"{path}: has too few items")
        if schema.get("uniqueItems") and len({json.dumps(item, sort_keys=True) for item in instance}) != len(instance):
            errors.append(f"{path}: items must be unique")
        for index, item in enumerate(instance):
            errors.extend(_basic_schema_errors(item, schema.get("items", {}), root, f"{path}[{index}]"))
    elif isinstance(instance, str):
        if len(instance) < schema.get("minLength", 0):
            errors.append(f"{path}: is too short")
        if "maxLength" in schema and len(instance) > schema["maxLength"]:
            errors.append(f"{path}: is too long")
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            errors.append(f"{path}: does not match {schema['pattern']}")
    elif isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(f"{path}: must be at least {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(f"{path}: must be at most {schema['maximum']}")
    return errors


def schema_errors(theme: dict[str, Any]) -> list[str]:
    schema = load_json(themes_dir() / "schema/theme.schema.json")
    try:
        import jsonschema

        validator = jsonschema.Draft202012Validator(schema)
        return [f"{'.'.join(str(part) for part in error.absolute_path) or '$'}: {error.message}" for error in sorted(validator.iter_errors(theme), key=lambda item: list(item.absolute_path))]
    except ImportError:
        return _basic_schema_errors(theme, schema, schema)


def _channel(value: int) -> float:
    normalised = value / 255
    return normalised / 12.92 if normalised <= 0.04045 else ((normalised + 0.055) / 1.055) ** 2.4


def contrast_ratio(first: str, second: str) -> float:
    def luminance(colour: str) -> float:
        channels = [_channel(int(colour[index:index + 2], 16)) for index in (1, 3, 5)]
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def _named_asset_exists(name: str, roots: tuple[Path, ...]) -> bool:
    return any((root / name).exists() for root in roots)


def dependency_checks(theme: dict[str, Any], targets: set[str] | None = None) -> CheckResult:
    result = CheckResult()
    enabled = lambda target: theme["targets"][target] and (targets is None or target in targets)
    wallpaper = Path(theme["wallpaper"]["path"]).expanduser()
    if enabled("wallpaper") and not wallpaper.is_file():
        result.errors.append(f"wallpaper does not exist: {wallpaper}")

    theme_roots = (Path.home() / ".local/share/themes", Path.home() / ".themes", Path("/usr/local/share/themes"), Path("/usr/share/themes"))
    icon_roots = (Path.home() / ".local/share/icons", Path.home() / ".icons", Path("/usr/local/share/icons"), Path("/usr/share/icons"))
    if enabled("gtk") and not _named_asset_exists(theme["gtk"]["base_theme"], theme_roots):
        result.errors.append(f"GTK base theme is not installed: {theme['gtk']['base_theme']}")
    if (enabled("vicinae") or enabled("gtk")) and not _named_asset_exists(theme["icons"]["theme"], icon_roots):
        result.errors.append(f"icon theme is not installed: {theme['icons']['theme']}")
    cursor = theme["cursor"]
    if enabled("cursor"):
        if cursor["mode"] == "installed" and not _named_asset_exists(cursor["base"], icon_roots):
            result.errors.append(f"cursor base is not installed: {cursor['base']}")
        elif cursor["mode"] == "generated":
            from .cursor import toolchain_check

            check = toolchain_check()
            if not check["ok"]:
                severity = result.errors if targets is not None and "cursor" in targets else result.warnings
                severity.append(f"cursor toolchain is not installed; run: {check['recovery']}")

    font_targets = ("quickshell", "vicinae", "widgets", "gtk", "kitty", "btop", "micro", "glow", "code", "cursor_editor", "stylus", "powerlevel10k", "sddm", "grub")
    fonts_enabled = any(enabled(target) for target in font_targets)
    if fonts_enabled and shutil.which("fc-match"):
        for role in ("ui", "mono", "panel"):
            requested = theme["fonts"][role]
            matched = subprocess.run(["fc-match", "-f", "%{family}", requested], check=False, capture_output=True, text=True).stdout.split(",", 1)[0]
            if matched.casefold() != requested.casefold():
                result.warnings.append(f"font {requested!r} resolves to {matched!r}")
    elif fonts_enabled:
        result.warnings.append("fc-match is unavailable; font dependencies were not checked")
    return result


def validate_theme(theme: dict[str, Any], check_dependencies: bool = True, targets: set[str] | None = None) -> CheckResult:
    result = CheckResult(errors=schema_errors(theme))
    if result.errors:
        return result
    bar_items = theme.get("shell", {}).get("bar", {}).get("items", [])
    bar_item_ids = [item["id"] for item in bar_items]
    if len(bar_item_ids) != len(set(bar_item_ids)):
        result.errors.append("shell.bar.items must not contain duplicate item ids")
    widget_items = theme.get("widgets", {}).get("items", [])
    widget_ids = [item["id"] for item in widget_items]
    if len(widget_ids) != len(set(widget_ids)):
        result.errors.append("widgets.items must not contain duplicate widget ids")
    colours = theme["colours"]
    pairs = (
        ("foreground", "background", 4.5),
        ("foreground", "surface", 4.5),
        ("muted", "background", 4.5),
        ("selection_foreground", "selection_background", 4.5),
        ("accent", "background", 3.0),
    )
    for foreground, background, minimum in pairs:
        ratio = contrast_ratio(colours[foreground], colours[background])
        if ratio < minimum:
            result.warnings.append(f"{foreground}/{background} contrast is {ratio:.2f}:1; recommends {minimum:.1f}:1")
    from .cursor import validate_cursor_theme

    cursor_errors, cursor_warnings = validate_cursor_theme(theme)
    result.errors.extend(cursor_errors)
    result.warnings.extend(cursor_warnings)
    generator = theme.get("generator")
    if generator:
        options = generator["options"]
        if options["mode"] != theme["variant"]:
            result.errors.append("generator options.mode must match the theme variant")
        backend_keys = {
            "matugen": {"mode", "scheme", "contrast", "source_colour_index"},
            "pywal": {"mode", "saturation"},
        }
        expected = backend_keys[generator["backend"]]
        if generator["backend"] == "matugen" and set(options) != expected:
            result.errors.append("matugen generator options must contain mode, scheme, contrast, and source_colour_index only")
        if generator["backend"] == "pywal" and not set(options).issubset(expected):
            result.errors.append("pywal generator options may contain mode and saturation only")
    gtk_override = theme.get("overrides", {}).get("gtk")
    if theme["gtk"]["mode"] == "generated" and theme["gtk"]["colour_source"] == "override" and not gtk_override:
        result.errors.append("generated GTK override colour source requires overrides.gtk")
    if theme["gtk"]["mode"] == "installed" and gtk_override:
        result.warnings.append("overrides.gtk is ignored in installed GTK mode")
    if theme["targets"]["gtk"] and theme["gtk"]["mode"] == "generated":
        gtk_colours = target_colours(theme, "gtk")
        for foreground, background, minimum in (("foreground", "background", 4.5), ("selection_foreground", "selection_background", 4.5), ("accent", "background", 3.0)):
            ratio = contrast_ratio(gtk_colours[foreground], gtk_colours[background])
            if ratio < minimum:
                result.warnings.append(f"GTK override {foreground}/{background} contrast is {ratio:.2f}:1; recommends {minimum:.1f}:1")
    if check_dependencies:
        dependencies = dependency_checks(theme, targets=targets)
        result.errors.extend(dependencies.errors)
        result.warnings.extend(dependencies.warnings)
    return result


def derive_ansi(theme: dict[str, Any]) -> dict[str, str]:
    colours = theme["colours"]
    roles = ("surface", "danger", "success", "warning", "info", "mauve", "teal", "muted", "surface_alt", "danger", "success", "warning", "info", "mauve", "teal", "foreground")
    derived = {f"color{index}": colours[role].lower() for index, role in enumerate(roles)}
    derived.update({key: value.lower() for key, value in theme.get("overrides", {}).get("ansi", {}).items()})
    return derived


def target_colours(theme: dict[str, Any], target: str) -> dict[str, str]:
    colours = {key: value.lower() for key, value in theme["colours"].items()}
    colours.update({key: value.lower() for key, value in theme.get("overrides", {}).get(target, {}).items()})
    return colours


def render_quickshell(theme: dict[str, Any], ansi: dict[str, str]) -> str:
    colours = target_colours(theme, "quickshell")
    shell = theme.get("shell", {
        "bar": {"position": "left"},
        "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
        "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
    })
    shell = {**shell, "bar": {**shell.get("bar", {}), "items": resolved_bar_items(shell.get("bar"))}}
    output = {
        "schema_version": 1,
        "id": theme["id"],
        "variant": theme["variant"],
        "colours": colours,
        "compatibility": {"red": colours["danger"], "green": colours["success"], "yellow": colours["warning"], "blue": colours["info"], "mauve": colours["mauve"], "teal": colours["teal"]},
        "fonts": {"ui": theme["fonts"]["ui"], "mono": theme["fonts"]["mono"], "panel": theme["fonts"]["panel"]},
        "ansi": ansi,
        "shell": shell,
    }
    return canonical_json(output)


def render_kitty(theme: dict[str, Any], ansi: dict[str, str]) -> str:
    colours = theme["colours"]
    terminal = theme["terminal"]
    lines = [
        "# Generated by themectl; edit the source theme, not this file.",
        f"foreground {colours['foreground'].lower()}", f"background {terminal['canvas'].lower()}",
        f"selection_foreground {colours['selection_foreground'].lower()}", f"selection_background {colours['selection_background'].lower()}",
        f"cursor {colours['accent'].lower()}", f"cursor_text_color {colours['selection_foreground'].lower()}", f"url_color {colours['info'].lower()}",
        f"active_border_color {colours['accent'].lower()}", f"inactive_border_color {colours['border'].lower()}", f"bell_border_color {colours['danger'].lower()}",
        f"active_tab_foreground {colours['background'].lower()}", f"active_tab_background {colours['foreground'].lower()}",
        f"inactive_tab_foreground {colours['foreground'].lower()}", f"inactive_tab_background {terminal['canvas'].lower()}",
        "tab_bar_background none", "",
    ]
    lines.extend(f"{key} {value}" for key, value in ansi.items())
    return "\n".join(lines) + "\n"


def render_vicinae(theme: dict[str, Any]) -> str:
    c = target_colours(theme, "vicinae")
    name = theme["name"].replace('"', '\\"')
    return f'''# Generated by themectl; edit the source theme, not this file.
[meta]
version = 1
name = "{name}"
description = "Generated from the {theme['id']} theme."
variant = "{theme['variant']}"
inherits = "vicinae-{theme['variant']}"

[colors.core]
background = "{c['background']}"
foreground = "{c['foreground']}"
secondary_background = "{c['surface']}"
border = "{c['border']}"
accent = "{c['accent']}"
accent_foreground = "{c['selection_foreground']}"

[colors.main_window]
border = "{c['border']}"
footer = {{ background = "{c['surface']}" }}

[colors.settings_window]
border = "{c['border']}"

[colors.accents]
blue = "{c['info']}"
green = "{c['success']}"
magenta = "{c['mauve']}"
orange = "{c['warning']}"
purple = "{c['mauve']}"
red = "{c['danger']}"
yellow = "{c['warning']}"
cyan = "{c['teal']}"

[colors.shortcut]
border = "{c['border']}"

[colors.text]
default = "{c['foreground']}"
muted = "{c['muted']}"
danger = "{c['danger']}"
success = "{c['success']}"
placeholder = "{c['muted']}"
selection = {{ background = "{c['selection_background']}", foreground = "{c['selection_foreground']}" }}

[colors.text.links]
default = "{c['info']}"
visited = "{c['mauve']}"

[colors.input]
border = "{c['border']}"
border_focus = "{c['accent']}"
border_error = "{c['danger']}"

[colors.button.primary]
background = "{c['surface']}"
foreground = "{c['foreground']}"
hover = {{ background = "{c['surface_alt']}" }}
focus = {{ outline = "{c['accent']}" }}

[colors.list.item.hover]
foreground = "{c['foreground']}"
secondary_foreground = "{c['foreground']}"

[colors.list.item.selection]
background = "{c['surface_alt']}"
foreground = "{c['foreground']}"
secondary_background = "{c['surface']}"
secondary_foreground = "{c['muted']}"

[colors.grid.item]
background = "{c['surface']}"
hover = {{ outline = "{c['accent']}" }}
selection = {{ outline = "{c['accent']}" }}

[colors.scrollbars]
background = "{c['surface_alt']}"

[colors.loading]
bar = "{c['accent']}"
spinner = "{c['foreground']}"
'''


def render_wallpaper(theme: dict[str, Any]) -> str:
    return canonical_json({"schema_version": 1, "path": theme["wallpaper"]["path"], "fit": theme["wallpaper"]["fit"]})


def render_gtk_settings(theme: dict[str, Any]) -> str:
    cursor_size = theme["cursor"]["sizes"][0]
    cursor_name = "blox-generated" if theme["cursor"]["mode"] == "generated" else theme["cursor"]["base"]
    prefer_dark = 1 if theme["variant"] == "dark" else 0
    lines = [
        "[Settings]",
        f"gtk-theme-name={theme['gtk']['base_theme']}",
        f"gtk-icon-theme-name={theme['icons']['theme']}",
        f"gtk-font-name={theme['fonts']['ui']} {theme['fonts']['gtk_size']}",
        f"gtk-cursor-theme-name={cursor_name}",
        f"gtk-cursor-theme-size={cursor_size}",
        f"gtk-application-prefer-dark-theme={prefer_dark}",
    ]
    return "\n".join(lines) + "\n"


def _gtk_definitions(theme: dict[str, Any]) -> str:
    colours = target_colours(theme, "gtk")
    roles = {
        "blox_bg": colours["background"],
        "blox_surface": colours["surface"],
        "blox_surface_alt": colours["surface_alt"],
        "blox_fg": colours["foreground"],
        "blox_muted": colours["muted"],
        "blox_accent": colours["accent"],
        "blox_selection_bg": colours["selection_background"],
        "blox_selection_fg": colours["selection_foreground"],
        "blox_border": colours["border"],
        "blox_success": colours["success"],
        "blox_warning": colours["warning"],
        "blox_danger": colours["danger"],
    }
    aliases = {
        "theme_bg_color": "blox_bg",
        "theme_fg_color": "blox_fg",
        "theme_base_color": "blox_surface",
        "theme_text_color": "blox_fg",
        "theme_selected_bg_color": "blox_selection_bg",
        "theme_selected_fg_color": "blox_selection_fg",
        "accent_bg_color": "blox_accent",
        "accent_fg_color": "blox_selection_fg",
        "success_color": "blox_success",
        "warning_color": "blox_warning",
        "error_color": "blox_danger",
    }
    lines = ["/* Generated by themectl; edit the source theme, not this file. */"]
    lines.extend(f"@define-color {name} {value};" for name, value in roles.items())
    lines.extend(f"@define-color {name} @{source};" for name, source in aliases.items())
    return "\n".join(lines)


def render_gtk3(theme: dict[str, Any]) -> str:
    return _gtk_definitions(theme) + """

window,
.background,
.gtkstyle-fallback {
  background-color: @blox_bg;
  color: @blox_fg;
}

headerbar,
.titlebar,
toolbar,
menubar,
menu {
  background-color: @blox_surface;
  color: @blox_fg;
  border-color: @blox_border;
}

button,
entry,
spinbutton,
combobox box.linked button {
  background-image: none;
  background-color: @blox_surface;
  color: @blox_fg;
  border-color: @blox_border;
}

button:hover,
row:hover,
menuitem:hover {
  background-image: none;
  background-color: @blox_surface_alt;
}

button:checked,
button:active,
switch:checked,
scale highlight,
progressbar progress {
  background-image: none;
  background-color: @blox_accent;
  color: @blox_selection_fg;
  border-color: @blox_accent;
}

entry selection,
label selection,
textview text selection,
treeview.view:selected,
row:selected {
  background-color: @blox_selection_bg;
  color: @blox_selection_fg;
}

textview text,
iconview,
.view {
  background-color: @blox_surface;
  color: @blox_fg;
}

*:disabled {
  color: @blox_muted;
}

*:focus {
  outline-color: @blox_accent;
}

.success { color: @blox_success; }
.warning { color: @blox_warning; }
.error { color: @blox_danger; }
"""


def render_gtk4(theme: dict[str, Any]) -> str:
    return _gtk_definitions(theme) + """

window {
  background-color: @blox_bg;
  color: @blox_fg;
}

headerbar,
.titlebar,
toolbar,
popover > contents,
menu {
  background-color: @blox_surface;
  color: @blox_fg;
  border-color: @blox_border;
}

button,
entry,
spinbutton,
dropdown > button {
  background-image: none;
  background-color: @blox_surface;
  color: @blox_fg;
  border-color: @blox_border;
}

button:hover,
row:hover {
  background-image: none;
  background-color: @blox_surface_alt;
}

button:checked,
button:active,
switch:checked,
scale highlight,
progressbar progress {
  background-image: none;
  background-color: @blox_accent;
  color: @blox_selection_fg;
  border-color: @blox_accent;
}

entry selection,
label selection,
textview text selection,
columnview row:selected,
listview row:selected,
gridview > child:selected {
  background-color: @blox_selection_bg;
  color: @blox_selection_fg;
}

textview text,
.view {
  background-color: @blox_surface;
  color: @blox_fg;
}

*:disabled {
  color: @blox_muted;
}

*:focus-visible {
  outline-color: @blox_accent;
}

.success { color: @blox_success; }
.warning { color: @blox_warning; }
.error { color: @blox_danger; }
"""


def render_gtk(theme: dict[str, Any]) -> dict[str, str]:
    settings = render_gtk_settings(theme)
    metadata = {
        "schema_version": 1,
        "mode": theme["gtk"]["mode"],
        "base_theme": theme["gtk"]["base_theme"],
        "font": f"{theme['fonts']['ui']} {theme['fonts']['gtk_size']}",
        "generated_css": theme["gtk"]["mode"] == "generated",
        "restart_required": True,
        "libadwaita_support": "partial-user-css",
    }
    files = {
        "gtk/gtk-3.0/settings.ini": settings,
        "gtk/gtk-4.0/settings.ini": settings,
        "gtk/metadata.json": canonical_json(metadata),
    }
    if theme["gtk"]["mode"] == "generated":
        files["gtk/gtk-3.0/gtk.css"] = render_gtk3(theme)
        files["gtk/gtk-4.0/gtk.css"] = render_gtk4(theme)
    return files


def _rgba(colour: str, alpha: str = "ff") -> str:
    return colour.removeprefix("#").lower() + alpha


def render_hyprland(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    return """-- Generated by themectl; edit the source theme, not this file.
hl.config({
    general = { col = {
        active_border = { colors = { \"rgba(%s)\", \"rgba(%s)\" }, angle = 45 },
        inactive_border = \"rgba(%s)\",
    } },
    decoration = { shadow = { color = \"rgba(%s)\" } },
})
""" % (_rgba(c["accent"], "ee"), _rgba(c["success"], "ee"), _rgba(c["border"], "aa"), _rgba(c["background"], "ee"))


def render_hyprtoolkit(theme: dict[str, Any]) -> str:
    c = theme["colours"]

    def argb(colour: str) -> str:
        return f"0xFF{colour.removeprefix('#').upper()}"

    return """# Generated by themectl; edit the source theme, not this file.
background = %s
base = %s
text = %s
alternate_base = %s
bright_text = %s
accent = %s
accent_secondary = %s
icon_theme = %s
font_family = %s
font_family_monospace = %s
""" % (
        argb(c["background"]),
        argb(c["surface"]),
        argb(c["foreground"]),
        argb(c["surface_alt"]),
        argb(c["foreground"]),
        argb(c["accent"]),
        argb(c["info"]),
        theme["icons"]["theme"],
        theme["fonts"]["ui"],
        theme["fonts"]["mono"],
    )


def render_hyprlock(theme: dict[str, Any]) -> str:
    c = target_colours(theme, "hyprlock")
    values = {
        "font": theme["fonts"]["panel"], "background": _rgba(c["background"], "cc"),
        "surface": _rgba(c["surface"], "e6"), "surface_alt": _rgba(c["surface_alt"]),
        "foreground": c["foreground"].removeprefix("#"), "muted": c["muted"].removeprefix("#"),
        "red": c["danger"].removeprefix("#"), "yellow": c["warning"].removeprefix("#"),
        "blue": c["accent"].removeprefix("#"),
    }
    return "# Generated by themectl; edit the source theme, not this file.\n" + "\n".join(f"${key} = {'rgba' if key in {'background', 'surface', 'surface_alt'} else 'rgb'}({value})" if key != "font" else f"$font = {value}" for key, value in values.items()) + "\n"


def render_btop(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    roles = {
        "main_bg": "background", "main_fg": "foreground", "title": "foreground", "hi_fg": "accent",
        "selected_bg": "selection_background", "selected_fg": "selection_foreground", "inactive_fg": "muted",
        "proc_misc": "info", "cpu_box": "border", "mem_box": "border", "net_box": "border", "proc_box": "border", "div_line": "border",
        "temp_start": "success", "temp_mid": "warning", "temp_end": "danger", "cpu_start": "success", "cpu_mid": "warning", "cpu_end": "danger",
        "free_start": "info", "free_mid": "mauve", "free_end": "teal", "cached_start": "info", "cached_mid": "mauve", "cached_end": "danger",
        "available_start": "info", "available_mid": "mauve", "available_end": "success", "used_start": "success", "used_mid": "warning", "used_end": "danger",
        "download_start": "info", "download_mid": "mauve", "download_end": "teal", "upload_start": "teal", "upload_mid": "mauve", "upload_end": "info",
    }
    return "# Generated by themectl; edit the source theme, not this file.\n" + "\n".join(f'theme[{key}]="{c[role].lower()}"' for key, role in roles.items()) + "\n"


def render_micro(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    links = {
        "default": c["foreground"], "comment": c["muted"], "identifier": c["foreground"],
        "constant": c["mauve"], "statement": c["accent"], "symbol": c["teal"], "preproc": c["warning"],
        "type": c["success"], "special": c["info"], "underlined": c["info"], "error": c["danger"],
        "todo": f'{c["background"]},{c["warning"]}', "statusline": f'{c["foreground"]},{c["surface_alt"]}',
        "tabbar": f'{c["muted"]},{c["surface"]}', "indent-char": c["border"], "selection": f'{c["selection_foreground"]},{c["selection_background"]}',
    }
    return "# Generated by themectl; edit the source theme, not this file.\n" + "\n".join(f'color-link {key} \"{value.lower()}\"' for key, value in links.items()) + "\n"


def render_glow(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    colour = lambda role: c[role].lower()
    style = {
        "document": {"block_prefix": "", "block_suffix": "", "color": colour("foreground")},
        "heading": {"block_suffix": "\n", "color": colour("accent"), "bold": True},
        "paragraph": {"color": colour("foreground")}, "text": {"color": colour("foreground")},
        "link": {"color": colour("info"), "underline": True}, "link_text": {"color": colour("accent")},
        "code": {"color": colour("teal")}, "code_block": {"color": colour("foreground"), "background_color": colour("surface")},
        "blockquote": {"color": colour("muted"), "indent": 1, "indent_token": "│ "},
        "list": {"color": colour("foreground")}, "item": {"block_prefix": "• "},
    }
    return canonical_json(style)


def editor_colours(theme: dict[str, Any]) -> dict[str, str]:
    c = theme["colours"]
    custom = {
        "editor.background": c["background"], "editor.foreground": c["foreground"], "editor.selectionBackground": c["selection_background"],
        "editor.inactiveSelectionBackground": c["surface_alt"], "editorCursor.foreground": c["accent"], "editorLineNumber.foreground": c["muted"],
        "editorGroupHeader.tabsBackground": c["surface"], "editorGroup.border": c["border"],
        "tab.activeBackground": c["background"], "tab.activeForeground": c["foreground"], "tab.activeBorderTop": c["accent"],
        "tab.inactiveBackground": c["surface"], "tab.inactiveForeground": c["muted"], "tab.border": c["border"],
        "activityBar.background": c["surface"], "activityBar.foreground": c["foreground"], "activityBar.inactiveForeground": c["muted"],
        "activityBar.border": c["border"], "activityBarBadge.background": c["accent"], "activityBarBadge.foreground": c["background"],
        "sideBar.background": c["surface"], "sideBar.foreground": c["foreground"], "sideBar.border": c["border"],
        "sideBarTitle.foreground": c["foreground"], "sideBarSectionHeader.background": c["surface_alt"],
        "sideBarSectionHeader.foreground": c["foreground"], "sideBarSectionHeader.border": c["border"],
        "list.activeSelectionBackground": c["selection_background"], "list.activeSelectionForeground": c["selection_foreground"],
        "list.inactiveSelectionBackground": c["surface_alt"], "list.inactiveSelectionForeground": c["foreground"],
        "list.hoverBackground": c["surface_alt"], "list.hoverForeground": c["foreground"], "list.focusOutline": c["accent"],
        "gitDecoration.addedResourceForeground": c["success"], "gitDecoration.modifiedResourceForeground": c["warning"],
        "gitDecoration.deletedResourceForeground": c["danger"], "gitDecoration.untrackedResourceForeground": c["teal"],
        "panel.background": c["surface"], "panel.border": c["border"], "panelTitle.activeForeground": c["foreground"],
        "panelTitle.inactiveForeground": c["muted"], "panelTitle.activeBorder": c["accent"],
        "titleBar.activeBackground": c["surface"], "titleBar.activeForeground": c["foreground"], "titleBar.border": c["border"],
        "statusBar.background": c["surface_alt"], "statusBar.foreground": c["foreground"], "statusBar.border": c["border"],
        "input.background": c["background"], "input.foreground": c["foreground"], "input.border": c["border"],
        "dropdown.background": c["surface_alt"], "dropdown.foreground": c["foreground"], "dropdown.border": c["border"],
        "menu.background": c["surface"], "menu.foreground": c["foreground"], "menu.selectionBackground": c["selection_background"],
        "badge.background": c["accent"], "badge.foreground": c["background"],
        "focusBorder": c["accent"], "errorForeground": c["danger"],
    }
    return custom


def render_editor(theme: dict[str, Any]) -> str:
    """Render the small settings fragment shared by Code and Cursor.

    Code receives its colours from a generated extension rather than from
    ``workbench.colorCustomizations``. Cursor retains this fragment until it
    grows an equivalent packaged-theme installer.
    """
    return canonical_json({"workbench.colorTheme": "Blox Dark 2026", "editor.fontFamily": theme["fonts"]["mono"], "editor.fontSize": theme["fonts"]["editor_size"]})


def render_cursor_editor(theme: dict[str, Any]) -> str:
    return canonical_json({"workbench.colorTheme": "Dark 2026", "editor.fontFamily": theme["fonts"]["mono"], "editor.fontSize": theme["fonts"]["editor_size"], "workbench.colorCustomizations": editor_colours(theme)})


def render_code_extension(theme: dict[str, Any]) -> dict[str, str]:
    package = {
        "name": "blox-dark-2026", "displayName": "Blox Dark 2026",
        "description": "Generated Blox colour theme based on Visual Studio Code Dark 2026.",
        "version": "1.0.0", "publisher": "blox", "engines": {"vscode": "*"},
        "categories": ["Themes"],
        "contributes": {"themes": [{"id": "Blox Dark 2026", "label": "Blox Dark 2026", "uiTheme": "vs-dark", "path": "./themes/blox-dark-2026.json"}]},
    }
    c = theme["colours"]
    colour_theme = {
        "$schema": "vscode://schemas/color-theme", "name": "Blox Dark 2026",
        "type": "dark", "semanticHighlighting": True,
        "colors": editor_colours(theme),
        # Dark 2026 uses the GitHub dark token palette. Preserve that language
        # while applying the canonical semantic roles to the workbench.
        "tokenColors": [
            {"scope": ["comment", "punctuation.definition.comment"], "settings": {"foreground": c["muted"]}},
            {"scope": ["keyword", "storage", "storage.type"], "settings": {"foreground": c["danger"]}},
            {"scope": ["string", "string.quoted"], "settings": {"foreground": c["info"]}},
            {"scope": ["entity.name.function"], "settings": {"foreground": c["mauve"]}},
            {"scope": ["entity.name.tag", "support.class.component"], "settings": {"foreground": c["success"]}},
            {"scope": ["constant", "support", "meta.property-name"], "settings": {"foreground": c["info"]}},
        ],
    }
    return {
        "code/package.json": canonical_json(package),
        "code/themes/blox-dark-2026.json": canonical_json(colour_theme),
        "code/settings.json": render_editor(theme),
    }


def render_stylus(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    variables = "\n".join(f"  --blox-{key.replace('_', '-')}: {value.lower()};" for key, value in c.items())
    return f"""/* ==UserStyle==
@name Blox System Theme
@namespace blox.local
@version 1.0.0
@description Generated by themectl; re-import after applying a new theme.
==/UserStyle== */
@-moz-document regexp(\"https?://.*\") {{
:root {{
{variables}
}}
::selection {{ background: var(--blox-selection-background); color: var(--blox-selection-foreground); }}
input, textarea, select, button {{ border-color: var(--blox-border); }}
a {{ color: var(--blox-info); }}
scrollbar, ::-webkit-scrollbar-track {{ background: var(--blox-surface); }}
::-webkit-scrollbar-thumb {{ background: var(--blox-muted); }}
}}
"""


def render_obsidian(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    # Keys follow Minimal's Style Settings export format. Keeping this as an
    # import document avoids modifying an arbitrary vault behind the user's
    # back and composes with Minimal instead of replacing it with a snippet.
    settings = {
        "minimal-style@@bg1@@dark": c["background"],
        "minimal-style@@bg2@@dark": c["surface"],
        "minimal-style@@bg3@@dark": c["surface_alt"],
        "minimal-style@@ui1@@dark": c["border"],
        "minimal-style@@ui2@@dark": c["muted"],
        "minimal-style@@ui3@@dark": c["accent"],
        "minimal-style@@tx1@@dark": c["foreground"],
        "minimal-style@@tx2@@dark": c["muted"],
        "minimal-style@@ax1@@dark": c["accent"],
        "minimal-style@@ax2@@dark": c["info"],
        "minimal-style@@red@@dark": c["danger"],
        "minimal-style@@yellow@@dark": c["warning"],
        "minimal-style@@green@@dark": c["success"],
        "minimal-style@@cyan@@dark": c["teal"],
        "minimal-style@@blue@@dark": c["info"],
        "minimal-style@@purple@@dark": c["mauve"],
    }
    return canonical_json(settings)


def render_powerlevel10k(theme: dict[str, Any]) -> str:
    c = theme["colours"]
    return """# Generated by themectl; edit the source theme, not this file.
typeset -g POWERLEVEL9K_BACKGROUND=%s
typeset -g POWERLEVEL9K_FOREGROUND=%s
typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=%s
typeset -g POWERLEVEL9K_DIR_BACKGROUND=%s
typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=%s
typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=%s
typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=%s
""" % (c["surface"], c["foreground"], c["mauve"], c["accent"], c["success"], c["warning"], c["danger"])


def render_widgets(theme: dict[str, Any]) -> str:
    widgets = theme.get("widgets", {})
    profile = widgets.get("profile", "minimal")
    profiles = {
        "minimal": {"opacity": 0.3, "margin": 20, "padding": 20, "radius": 0, "font_size": 14},
        "compact": {"opacity": 0.52, "margin": 12, "padding": 12, "radius": 6, "font_size": 12},
        "comfortable": {"opacity": 0.42, "margin": 24, "padding": 24, "radius": 10, "font_size": 15},
    }
    defaults = [
        {"id": "todo", "name": "Todo", "type": "custom", "enabled": True, "content_command": "$SCRIPT_ROOT/overlays/todo-content.sh", "left_click_command": "$SCRIPT_ROOT/overlays/cycle-todo.sh", "right_click_command": "$SCRIPT_ROOT/overlays/open-todo-editor.sh", "interval_ms": 60000, "visibility": "empty-workspace", "anchor": "top-left", "offset_x": 20, "offset_y": 20, "width": 0, "height": 0, "shape": "auto", "options": {}},
        {"id": "calendar", "name": "Calendar", "type": "custom", "enabled": True, "content_command": "$SCRIPT_ROOT/overlays/gcal-content.sh", "left_click_command": "$SCRIPT_ROOT/overlays/cycle-gcal.sh", "right_click_command": "$SCRIPT_ROOT/overlays/open-gcal.sh", "interval_ms": 60000, "visibility": "empty-workspace", "anchor": "bottom-right", "offset_x": 20, "offset_y": 20, "width": 0, "height": 0, "shape": "auto", "options": {}},
    ]
    return canonical_json({"schema_version": 1, "profile": profile, **profiles[profile], "items": widgets.get("items", defaults)})


def render_theme(theme: dict[str, Any]) -> tuple[dict[str, str], list[str]]:
    ansi = derive_ansi(theme)
    files: dict[str, str] = {}
    targets = theme["targets"]
    if targets["quickshell"]:
        files["quickshell/theme.json"] = render_quickshell(theme, ansi)
    if targets["vicinae"]:
        files["vicinae/theme.toml"] = render_vicinae(theme)
    if targets["kitty"]:
        files["kitty/theme.conf"] = render_kitty(theme, ansi)
    if targets["wallpaper"]:
        files["hypr/wallpaper.json"] = render_wallpaper(theme)
    if targets["gtk"]:
        files.update(render_gtk(theme))
    if targets["cursor"]:
        from .cursor import cursor_metadata

        files["cursor/metadata.json"] = canonical_json(cursor_metadata(theme))
    if targets["hyprland"]:
        files["hyprland/theme.lua"] = render_hyprland(theme)
        files["hyprland/hyprtoolkit.conf"] = render_hyprtoolkit(theme)
    if targets["hyprlock"]:
        files["hyprlock/theme.conf"] = render_hyprlock(theme)
    if targets["btop"]:
        files["btop/theme.theme"] = render_btop(theme)
    if targets["micro"]:
        files["micro/blox-theme.micro"] = render_micro(theme)
    if targets["glow"]:
        files["glow/style.json"] = render_glow(theme)
    if targets["code"]:
        files.update(render_code_extension(theme))
    if targets["cursor_editor"]:
        files["cursor-editor/settings.json"] = render_cursor_editor(theme)
    if targets["stylus"]:
        files["stylus/blox-system.user.css"] = render_stylus(theme)
    if targets.get("obsidian", False):
        files["obsidian/style-settings.json"] = render_obsidian(theme)
    if targets["powerlevel10k"]:
        files["powerlevel10k/theme.zsh"] = render_powerlevel10k(theme)
    if targets["widgets"]:
        files["widgets/profile.json"] = render_widgets(theme)
    warnings = [message for target, message in {**DEFERRED_TARGETS, **TARGET_LIMITATIONS}.items() if targets.get(target, False)]
    return dict(sorted(files.items())), warnings


def render_manifest(theme_path_value: Path, theme: dict[str, Any], files: dict[str, str]) -> dict[str, Any]:
    source = canonical_json(theme)
    return {
        "schema_version": 1,
        "renderer_version": RENDERER_VERSION,
        "source": str(theme_path_value.resolve()),
        "source_sha256": sha256_text(source),
        "theme_id": theme["id"],
        "files": {name: sha256_text(content) for name, content in files.items()},
        "derived": {"ansi": derive_ansi(theme)},
    }


def write_render(output: Path, files: dict[str, str], manifest: dict[str, Any]) -> None:
    resolved_output = output.expanduser().resolve()
    resolved_state = state_dir().resolve()
    if resolved_output == resolved_state or resolved_state in resolved_output.parents:
        raise ValueError("render output must not be inside the live theme state directory")
    if resolved_output.exists() and any(resolved_output.iterdir()):
        raise ValueError(f"render output is not empty: {resolved_output}")
    output = resolved_output
    output.mkdir(parents=True, exist_ok=True)
    for name, content in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    (output / "manifest.json").write_text(canonical_json(manifest), encoding="utf-8")


def rendered_diff(files: dict[str, str]) -> list[dict[str, Any]]:
    current = state_dir() / "current"
    changes = []
    for name, content in files.items():
        live = current / name
        old = live.read_text(encoding="utf-8") if live.is_file() else None
        changes.append({"path": name, "change": "add" if old is None else "unchanged" if old == content else "modify", "old_sha256": sha256_text(old) if old is not None else None, "new_sha256": sha256_text(content)})
    return changes
