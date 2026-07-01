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

IMPLEMENTED_TARGETS = ("quickshell", "vicinae", "kitty", "wallpaper")
DEFERRED_TARGETS = {
    "widgets": "widget profiles are implemented in Phase 9",
    "gtk": "GTK rendering follows the Phase 3 compatibility spike",
    "cursor": "generated cursor rendering is implemented in Phase 5",
}


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
            entries.append({"id": data.get("id", path.stem), "name": data.get("name", path.stem), "variant": data.get("variant"), "path": str(path)})
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
    if enabled("cursor") and not _named_asset_exists(cursor["base"], icon_roots):
        severity = result.warnings if cursor["mode"] == "generated" else result.errors
        severity.append(f"cursor base is not installed: {cursor['base']}")

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
            result.errors.append(f"{foreground}/{background} contrast is {ratio:.2f}:1; requires {minimum:.1f}:1")
    if theme["cursor"]["mode"] == "generated":
        cursor = theme["cursor"]
        if contrast_ratio(cursor.get("base_colour", colours["accent"]), cursor.get("outline_colour", colours["foreground"])) < 3:
            result.errors.append("generated cursor base/outline contrast requires 3.0:1")
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
    output = {
        "schema_version": 1,
        "id": theme["id"],
        "variant": theme["variant"],
        "colours": colours,
        "compatibility": {"red": colours["danger"], "green": colours["success"], "yellow": colours["warning"], "blue": colours["info"], "mauve": colours["mauve"], "teal": colours["teal"]},
        "fonts": {"ui": theme["fonts"]["ui"], "mono": theme["fonts"]["mono"], "panel": theme["fonts"]["panel"]},
        "ansi": ansi,
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
        f"inactive_tab_foreground {colours['foreground'].lower()}", f"inactive_tab_background {terminal['chrome_background'].lower()}",
        f"tab_bar_background {terminal['chrome_background'].lower()}", "",
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
    warnings = [message for target, message in DEFERRED_TARGETS.items() if targets[target]]
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
