from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import uuid
from contextlib import AbstractContextManager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable

from . import RENDERER_VERSION
from .core import canonical_json, render_theme, repository_root, sha256_text, state_dir


TARGET_FILES = {
    "quickshell": ("quickshell/theme.json",),
    "vicinae": ("vicinae/theme.toml",),
    "kitty": ("kitty/theme.conf",),
    "wallpaper": ("hypr/wallpaper.json",),
    "gtk": ("gtk/gtk-3.0/settings.ini", "gtk/gtk-3.0/gtk.css", "gtk/gtk-4.0/settings.ini", "gtk/gtk-4.0/gtk.css", "gtk/metadata.json"),
}
TARGET_REQUIRED_FILES = {
    **{target: files for target, files in TARGET_FILES.items() if target != "gtk"},
    "gtk": ("gtk/gtk-3.0/settings.ini", "gtk/gtk-4.0/settings.ini", "gtk/metadata.json"),
}
TARGET_NAMES = tuple(TARGET_FILES)
GENERATION_PATTERN = re.compile(r"^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{8}$")
HISTORY_LIMIT = 5


class RuntimeFailure(Exception):
    """A safe, user-facing runtime failure."""


class LockContended(RuntimeFailure):
    """Another mutating theme operation owns the application lock."""


def _fsync_directory(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as handle:
        handle.write(content)
        handle.flush()
        os.fsync(handle.fileno())


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _target_for_file(name: str) -> str | None:
    for target, names in TARGET_FILES.items():
        if name in names:
            return target
    return None


def configured_targets(theme: dict[str, Any], requested: str | Iterable[str] | None = None) -> tuple[str, ...]:
    if requested is None:
        return tuple(target for target in TARGET_NAMES if theme["targets"][target])
    values = requested.split(",") if isinstance(requested, str) else list(requested)
    targets = tuple(dict.fromkeys(value.strip() for value in values if value.strip()))
    if not targets:
        raise RuntimeFailure("at least one target is required")
    unknown = sorted(set(targets) - set(TARGET_NAMES))
    if unknown:
        raise RuntimeFailure(f"unsupported Phase 2 target(s): {', '.join(unknown)}")
    disabled = [target for target in targets if not theme["targets"][target]]
    if disabled:
        raise RuntimeFailure(f"target(s) disabled by theme: {', '.join(disabled)}")
    return targets


class ApplicationLock(AbstractContextManager["ApplicationLock"]):
    def __init__(self, root: Path | None = None) -> None:
        self.root = root or state_dir()
        self.handle: Any = None

    def __enter__(self) -> "ApplicationLock":
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        try:
            self.root.chmod(0o700)
        except OSError:
            pass
        lock_path = self.root / "lock"
        self.handle = lock_path.open("a+", encoding="utf-8")
        try:
            os.chmod(lock_path, 0o600)
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            self.handle.close()
            self.handle = None
            raise LockContended("another theme operation is already running") from error
        self.handle.seek(0)
        self.handle.truncate()
        self.handle.write(f"pid={os.getpid()}\n")
        self.handle.flush()
        return self

    def __exit__(self, exc_type: Any, exc_value: Any, traceback: Any) -> None:
        if self.handle is not None:
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
            self.handle.close()
            self.handle = None


def _generation_path_from_current(root: Path) -> Path | None:
    current = root / "current"
    if not current.is_symlink():
        if current.exists():
            raise RuntimeFailure(f"theme current path is not a symlink: {current}")
        return None
    resolved = current.resolve(strict=True)
    generations = (root / "generations").resolve()
    if resolved.parent != generations or not GENERATION_PATTERN.fullmatch(resolved.name):
        raise RuntimeFailure(f"theme current link escapes the generations directory: {current}")
    return resolved


def validate_generation(path: Path) -> dict[str, Any]:
    if not path.is_dir() or not GENERATION_PATTERN.fullmatch(path.name):
        raise RuntimeFailure(f"invalid generation: {path.name}")
    manifest_path = path / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeFailure(f"cannot read generation manifest: {manifest_path}") from error
    required = {"schema_version", "renderer_version", "generation_id", "created_at", "operation", "source", "source_sha256", "theme_id", "enabled_targets", "target_sources", "files", "derived"}
    if not isinstance(manifest, dict) or set(manifest) != required:
        raise RuntimeFailure(f"generation manifest has an invalid structure: {manifest_path}")
    if manifest["schema_version"] != 1 or manifest["generation_id"] != path.name:
        raise RuntimeFailure(f"generation manifest identity mismatch: {manifest_path}")
    try:
        datetime.fromisoformat(manifest["created_at"])
    except (TypeError, ValueError) as error:
        raise RuntimeFailure(f"generation timestamp is invalid: {manifest_path}") from error
    if not isinstance(manifest["renderer_version"], int) or manifest["renderer_version"] < 1:
        raise RuntimeFailure(f"generation renderer version is invalid: {manifest_path}")
    if not isinstance(manifest["operation"], str) or not isinstance(manifest["source"], str) or not isinstance(manifest["theme_id"], str):
        raise RuntimeFailure(f"generation metadata types are invalid: {manifest_path}")
    if not isinstance(manifest["source_sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", manifest["source_sha256"]):
        raise RuntimeFailure(f"generation source digest is invalid: {manifest_path}")
    if not isinstance(manifest["files"], dict) or not isinstance(manifest["enabled_targets"], list) or not isinstance(manifest["target_sources"], dict) or not isinstance(manifest["derived"], dict):
        raise RuntimeFailure(f"generation manifest types are invalid: {manifest_path}")
    if len(set(manifest["enabled_targets"])) != len(manifest["enabled_targets"]) or not set(manifest["enabled_targets"]).issubset(TARGET_FILES):
        raise RuntimeFailure(f"generation targets are invalid: {manifest_path}")
    actual_files = sorted(str(item.relative_to(path)) for item in path.rglob("*") if item.is_file() and item.name != "manifest.json")
    if actual_files != sorted(manifest["files"]):
        raise RuntimeFailure(f"generation file list does not match its manifest: {path.name}")
    for name, expected in manifest["files"].items():
        file_path = path / name
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected) or file_path.is_symlink() or _file_sha256(file_path) != expected:
            raise RuntimeFailure(f"generation file digest mismatch: {name}")
        if _target_for_file(name) not in manifest["enabled_targets"]:
            raise RuntimeFailure(f"generation target is not enabled for file: {name}")
    expected_targets = sorted(target for target, names in TARGET_FILES.items() if any((path / name).is_file() for name in names))
    if sorted(manifest["enabled_targets"]) != expected_targets or sorted(manifest["target_sources"]) != expected_targets:
        raise RuntimeFailure(f"generation target metadata is inconsistent: {path.name}")
    for target, source in manifest["target_sources"].items():
        if not isinstance(source, dict) or set(source) != {"theme_id", "source", "source_sha256"}:
            raise RuntimeFailure(f"generation target source is invalid: {target}")
        if not isinstance(source["theme_id"], str) or not isinstance(source["source"], str) or not re.fullmatch(r"[0-9a-f]{64}", source["source_sha256"]):
            raise RuntimeFailure(f"generation target source values are invalid: {target}")
    return manifest


def current_generation(root: Path | None = None) -> tuple[Path, dict[str, Any]] | None:
    root = root or state_dir()
    path = _generation_path_from_current(root)
    active = root / "active.json"
    if path is not None and (not active.is_symlink() or os.readlink(active) != "current/manifest.json"):
        raise RuntimeFailure(f"active manifest link is invalid: {active}")
    return (path, validate_generation(path)) if path else None


def _new_generation_id() -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{uuid.uuid4().hex[:8]}"


def _copy_previous(previous: Path | None, candidate: Path) -> None:
    if previous is None:
        return
    for target_files in TARGET_FILES.values():
        for name in target_files:
            source = previous / name
            if source.is_file():
                destination = candidate / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)


def _remove_target(candidate: Path, target: str) -> None:
    for name in TARGET_FILES[target]:
        path = candidate / name
        if path.exists():
            path.unlink()
        parent = path.parent
        while parent != candidate and parent.exists() and not any(parent.iterdir()):
            parent.rmdir()
            parent = parent.parent


def _manifest_files(candidate: Path) -> dict[str, str]:
    return {str(path.relative_to(candidate)): _file_sha256(path) for path in sorted(candidate.rglob("*")) if path.is_file() and path.name != "manifest.json"}


def _target_sources(previous_manifest: dict[str, Any] | None, selected: Iterable[str], theme_path: Path, theme: dict[str, Any]) -> dict[str, Any]:
    sources = dict(previous_manifest.get("target_sources", {})) if previous_manifest else {}
    source = {
        "theme_id": theme["id"],
        "source": str(theme_path.resolve()),
        "source_sha256": sha256_text(canonical_json(theme)),
    }
    for target in selected:
        sources[target] = source
    return sources


def _switch_generation(root: Path, generation: Path) -> None:
    temporary = root / f".current-{uuid.uuid4().hex}"
    temporary.symlink_to(Path("generations") / generation.name)
    os.replace(temporary, root / "current")
    active = root / "active.json"
    if not active.is_symlink() or os.readlink(active) != "current/manifest.json":
        temporary_active = root / f".active-{uuid.uuid4().hex}"
        temporary_active.symlink_to("current/manifest.json")
        os.replace(temporary_active, active)
    _fsync_directory(root)


def _prune_generations(root: Path, current: Path) -> None:
    generations = []
    for path in (root / "generations").iterdir():
        if path.is_dir() and GENERATION_PATTERN.fullmatch(path.name):
            generations.append(path)
        elif path.name.startswith(".candidate-"):
            shutil.rmtree(path, ignore_errors=True)
    previous = sorted((path for path in generations if path != current), key=lambda item: item.stat().st_mtime_ns, reverse=True)
    for path in previous[HISTORY_LIMIT:]:
        shutil.rmtree(path)


def _command_text(command: list[str]) -> str:
    return " ".join(command)


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, check=False, capture_output=True, text=True)
    except OSError as error:
        return subprocess.CompletedProcess(command, 127, "", str(error))


def quickshell_config_path() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return config_home / "quickshell/blox"


def vicinae_theme_link() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser()
    return data_home / "vicinae/themes/blox-generated.toml"


def kitty_config_path() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return config_home / "kitty/kitty.conf"


def kitty_include_line() -> str:
    return "globinclude blox-theme.conf"


def gtk_config_path(version: str) -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).expanduser()
    return config_home / f"gtk-{version}.0"


def gtk_source_path(version: str, name: str) -> Path:
    return repository_root() / f"gtk/.config/gtk-{version}.0/{name}"


def gtk_integration_path(root: Path) -> Path:
    return root / "integration/gtk-loaders.json"


def _load_gtk_integration(root: Path) -> dict[str, Any] | None:
    path = gtk_integration_path(root)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeFailure(f"GTK loader integration record is invalid: {path}") from error
    if not isinstance(data, dict) or set(data) != {"schema_version", "loaders"} or data["schema_version"] != 1:
        raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
    if not isinstance(data["loaders"], dict) or set(data["loaders"]) != {"3", "4"}:
        raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
    for version in ("3", "4"):
        entries = data["loaders"][version]
        if not isinstance(entries, dict) or set(entries) != {"gtk.css", "gtk-dark.css"}:
            raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
        for entry in entries.values():
            if not isinstance(entry, dict) or entry.get("kind") not in ("absent", "symlink"):
                raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
            if entry["kind"] == "symlink" and (set(entry) != {"kind", "target"} or not isinstance(entry["target"], str)):
                raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
            if entry["kind"] == "absent" and set(entry) != {"kind"}:
                raise RuntimeFailure(f"GTK loader integration record is invalid: {path}")
    return data


def _capture_gtk_integration() -> dict[str, Any]:
    loaders: dict[str, Any] = {}
    for version in ("3", "4"):
        entries = {}
        for name in ("gtk.css", "gtk-dark.css"):
            path = gtk_config_path(version) / name
            if path.is_symlink():
                entries[name] = {"kind": "symlink", "target": os.readlink(path)}
            elif path.exists():
                raise RuntimeFailure(f"refusing to replace regular GTK stylesheet: {path}")
            else:
                entries[name] = {"kind": "absent"}
        loaders[version] = entries
    return {"schema_version": 1, "loaders": loaders}


def _save_gtk_integration(root: Path, data: dict[str, Any]) -> None:
    path = gtk_integration_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent / f".{path.name}.{uuid.uuid4().hex}.tmp"
    _write_text(temporary, canonical_json(data))
    os.replace(temporary, path)
    _fsync_directory(path.parent)


def _ensure_gtk_integration(root: Path, allow_existing: bool) -> dict[str, Any]:
    existing = _load_gtk_integration(root)
    if existing:
        return existing
    captured = _capture_gtk_integration()
    has_existing = any(entry["kind"] != "absent" for entries in captured["loaders"].values() for entry in entries.values())
    if has_existing and not allow_existing:
        raise RuntimeFailure("existing GTK stylesheet loaders require explicit migration; run: themectl setup gtk --yes")
    _save_gtk_integration(root, captured)
    return captured


def kitty_theme_link() -> Path:
    return kitty_config_path().parent / "blox-theme.conf"


def ensure_vicinae_loader(root: Path) -> None:
    link = vicinae_theme_link()
    expected = root / "current/vicinae/theme.toml"
    if link.is_symlink() and Path(os.readlink(link)) == expected:
        return
    if link.exists() or link.is_symlink():
        raise RuntimeFailure(f"refusing to replace conflicting Vicinae theme loader: {link}")
    link.parent.mkdir(parents=True, exist_ok=True)
    temporary = link.parent / f".{link.name}.{uuid.uuid4().hex}.tmp"
    temporary.symlink_to(expected)
    os.replace(temporary, link)


def ensure_kitty_loader(root: Path) -> None:
    link = kitty_theme_link()
    expected = root / "current/kitty/theme.conf"
    if link.is_symlink() and Path(os.readlink(link)) == expected:
        return
    if link.exists() or link.is_symlink():
        raise RuntimeFailure(f"refusing to replace conflicting Kitty theme loader: {link}")
    link.parent.mkdir(parents=True, exist_ok=True)
    temporary = link.parent / f".{link.name}.{uuid.uuid4().hex}.tmp"
    temporary.symlink_to(expected)
    os.replace(temporary, link)


def _replace_known_symlink(link: Path, expected: Path, allowed: Iterable[Path]) -> None:
    allowed_targets = {str(path) for path in allowed}
    if link.is_symlink():
        current = os.readlink(link)
        if current == str(expected):
            return
        if current not in allowed_targets:
            raise RuntimeFailure(f"refusing to replace unexpected theme loader: {link}")
    elif link.exists():
        raise RuntimeFailure(f"refusing to replace conflicting theme loader: {link}")
    link.parent.mkdir(parents=True, exist_ok=True)
    temporary = link.parent / f".{link.name}.{uuid.uuid4().hex}.tmp"
    temporary.symlink_to(expected)
    os.replace(temporary, link)


def _gtk_metadata(root: Path) -> dict[str, Any]:
    path = root / "current/gtk/metadata.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeFailure(f"GTK metadata is invalid: {path}") from error
    if not isinstance(data, dict) or data.get("mode") not in ("generated", "installed") or not isinstance(data.get("generated_css"), bool):
        raise RuntimeFailure(f"GTK metadata is invalid: {path}")
    return data


def ensure_gtk_loaders(root: Path, active: bool) -> None:
    integration = _ensure_gtk_integration(root, allow_existing=False)
    metadata = _gtk_metadata(root) if active else None
    for version in ("3", "4"):
        config = gtk_config_path(version)
        source_settings = gtk_source_path(version, "settings.ini")
        live_settings = config / "settings.ini"
        generated_settings = root / f"current/gtk/gtk-{version}.0/settings.ini"
        generated_css = root / f"current/gtk/gtk-{version}.0/gtk.css"

        settings_target = generated_settings if active else source_settings
        _replace_known_symlink(live_settings, settings_target, (source_settings, generated_settings))
        for dark, loader_name, dynamic_name in ((False, "gtk.css", "blox-theme.css"), (True, "gtk-dark.css", "blox-theme-dark.css")):
            source_loader = gtk_source_path(version, loader_name)
            live_loader = config / loader_name
            entry = integration["loaders"][version][loader_name]
            original = Path(entry["target"]) if entry["kind"] == "symlink" else gtk_source_path(version, "blox-theme-empty-dark.css" if dark else "blox-theme-empty.css")
            allowed_loaders = [source_loader]
            if entry["kind"] == "symlink":
                allowed_loaders.append(Path(entry["target"]))
            _replace_known_symlink(live_loader, source_loader, allowed_loaders)
            dynamic_css = config / dynamic_name
            css_target = generated_css if active and metadata and metadata["generated_css"] else original
            _replace_known_symlink(dynamic_css, css_target, (original, generated_css))


def setup_gtk() -> dict[str, Any]:
    root = state_dir()
    with ApplicationLock(root):
        integration = _ensure_gtk_integration(root, allow_existing=True)
        changed = False
        for version in ("3", "4"):
            config = gtk_config_path(version)
            for name, entry in integration["loaders"][version].items():
                if entry["kind"] != "symlink":
                    continue
                target = Path(entry["target"])
                resolved = target if target.is_absolute() else config / target
                if not resolved.exists():
                    _replace_known_symlink(config / name, gtk_source_path(version, name), (target, gtk_source_path(version, name)))
                    integration["loaders"][version][name] = {"kind": "absent"}
                    changed = True
        if changed:
            _save_gtk_integration(root, integration)
        for version in ("3", "4"):
            config = gtk_config_path(version)
            for dark, loader_name, dynamic_name in ((False, "gtk.css", "blox-theme.css"), (True, "gtk-dark.css", "blox-theme-dark.css")):
                if integration["loaders"][version][loader_name]["kind"] != "absent":
                    continue
                dynamic = config / dynamic_name
                if dynamic.is_symlink():
                    target = Path(os.readlink(dynamic))
                    resolved = target if target.is_absolute() else config / target
                    if not resolved.exists():
                        fallback = gtk_source_path(version, "blox-theme-empty-dark.css" if dark else "blox-theme-empty.css")
                        _replace_known_symlink(dynamic, fallback, (target, fallback))
        record = current_generation(root)
        active = bool(record and "gtk" in record[1]["enabled_targets"])
        ensure_gtk_loaders(root, active)
        return integration


def _remove_managed_loader(link: Path, expected: Path) -> None:
    if not link.is_symlink():
        if link.exists():
            raise RuntimeFailure(f"refusing to remove conflicting theme loader: {link}")
        return
    if Path(os.readlink(link)) != expected:
        raise RuntimeFailure(f"refusing to remove unexpected theme loader: {link}")
    link.unlink()


def sync_dynamic_loaders(root: Path, enabled_targets: Iterable[str]) -> None:
    enabled = set(enabled_targets)
    vicinae = vicinae_theme_link()
    vicinae_expected = root / "current/vicinae/theme.toml"
    kitty = kitty_theme_link()
    kitty_expected = root / "current/kitty/theme.conf"
    if "vicinae" in enabled:
        ensure_vicinae_loader(root)
    else:
        _remove_managed_loader(vicinae, vicinae_expected)
    if "kitty" in enabled:
        ensure_kitty_loader(root)
    else:
        _remove_managed_loader(kitty, kitty_expected)
    if "gtk" in enabled:
        ensure_gtk_loaders(root, True)
    else:
        generated_links = []
        for version in ("3", "4"):
            config = gtk_config_path(version)
            generated_links.extend((
                (config / "settings.ini", root / f"current/gtk/gtk-{version}.0/settings.ini"),
                (config / "blox-theme.css", root / f"current/gtk/gtk-{version}.0/gtk.css"),
            ))
        if any(link.is_symlink() and os.readlink(link) == str(expected) for link, expected in generated_links):
            ensure_gtk_loaders(root, False)


def cleanup_managed_loaders(root: Path) -> None:
    pairs = (
        (vicinae_theme_link(), root / "current/vicinae/theme.toml"),
        (kitty_theme_link(), root / "current/kitty/theme.conf"),
    )
    for link, expected in pairs:
        if link.is_symlink() and Path(os.readlink(link)) == expected:
            link.unlink()
    if _load_gtk_integration(root):
        try:
            ensure_gtk_loaders(root, False)
        except RuntimeFailure:
            pass


def verify_tracked_loaders(targets: Iterable[str]) -> None:
    selected = set(targets)
    checks = loader_checks()
    required = []
    if "quickshell" in selected:
        required.append("quickshell_loader")
    if "kitty" in selected:
        required.append("kitty_loader")
    failures = [name for name in required if not checks[name]["ok"]]
    if failures:
        details = "; ".join(f"{name}: {checks[name]['path']}" for name in failures)
        raise RuntimeFailure(f"tracked theme loader is missing ({details})")
    if "gtk" in selected:
        source_names = ("settings.ini", "gtk.css", "gtk-dark.css", "blox-theme-empty.css", "blox-theme-empty-dark.css")
        missing = [str(gtk_source_path(version, name)) for version in ("3", "4") for name in source_names if not gtk_source_path(version, name).is_file()]
        if missing:
            raise RuntimeFailure(f"tracked GTK loader is missing: {', '.join(missing)}")
        integration = _load_gtk_integration(state_dir())
        if integration is None:
            for version in ("3", "4"):
                for name in ("gtk.css", "gtk-dark.css"):
                    path = gtk_config_path(version) / name
                    if path.exists() or path.is_symlink():
                        raise RuntimeFailure("existing GTK stylesheet loaders require explicit migration; run: themectl setup gtk --yes")
        for version in ("3", "4"):
            config = gtk_config_path(version)
            allowed = {
                "settings.ini": (gtk_source_path(version, "settings.ini"), state_dir() / f"current/gtk/gtk-{version}.0/settings.ini"),
                "blox-theme.css": (gtk_source_path(version, "blox-theme-empty.css"), state_dir() / f"current/gtk/gtk-{version}.0/gtk.css"),
                "blox-theme-dark.css": (gtk_source_path(version, "blox-theme-empty-dark.css"), state_dir() / f"current/gtk/gtk-{version}.0/gtk.css"),
            }
            if integration:
                light_original = integration["loaders"][version]["gtk.css"]
                dark_original = integration["loaders"][version]["gtk-dark.css"]
                if light_original["kind"] == "symlink":
                    allowed["blox-theme.css"] += (Path(light_original["target"]),)
                if dark_original["kind"] == "symlink":
                    allowed["blox-theme-dark.css"] += (Path(dark_original["target"]),)
            for loader_name in ("gtk.css", "gtk-dark.css"):
                allowed_targets = [gtk_source_path(version, loader_name)]
                if integration and integration["loaders"][version][loader_name]["kind"] == "symlink":
                    allowed_targets.append(Path(integration["loaders"][version][loader_name]["target"]))
                allowed[loader_name] = tuple(allowed_targets)
            for name, targets_allowed in allowed.items():
                path = config / name
                if path.exists() and not path.is_symlink():
                    raise RuntimeFailure(f"refusing to replace conflicting GTK loader: {path}")
                if path.is_symlink() and os.readlink(path) not in {str(item) for item in targets_allowed}:
                    raise RuntimeFailure(f"refusing to replace unexpected GTK loader: {path}")


def loader_checks(root: Path | None = None) -> dict[str, dict[str, Any]]:
    root = root or state_dir()
    vicinae = vicinae_theme_link()
    expected_vicinae = root / "current/vicinae/theme.toml"
    kitty_link = kitty_theme_link()
    expected_kitty = root / "current/kitty/theme.conf"
    kitty = kitty_config_path()
    quickshell = quickshell_config_path() / "shared/Theme.qml"
    startup = quickshell_config_path().parents[1] / "hypr/conf.d/autostart.lua"
    try:
        kitty_text = kitty.read_text(encoding="utf-8")
    except OSError:
        kitty_text = ""
    try:
        quickshell_text = quickshell.read_text(encoding="utf-8")
    except OSError:
        quickshell_text = ""
    try:
        startup_text = startup.read_text(encoding="utf-8")
    except OSError:
        startup_text = ""
    checks = {
        "quickshell_loader": {"ok": "watchChanges: true" in quickshell_text and "function loadJson" in quickshell_text, "path": str(quickshell)},
        "kitty_loader": {"ok": kitty_include_line() in kitty_text, "path": str(kitty), "expected": kitty_include_line()},
        "kitty_generated_link": {"ok": kitty_link.is_symlink() and Path(os.readlink(kitty_link)) == expected_kitty, "path": str(kitty_link), "expected": str(expected_kitty)},
        "vicinae_loader": {"ok": vicinae.is_symlink() and Path(os.readlink(vicinae)) == expected_vicinae, "path": str(vicinae), "expected": str(expected_vicinae)},
        "session_reconcile": {"ok": "scripts/theme/reconcile.sh" in startup_text, "path": str(startup)},
    }
    for version in ("3", "4"):
        light_loader = gtk_source_path(version, "gtk.css")
        dark_loader = gtk_source_path(version, "gtk-dark.css")
        live_light = gtk_config_path(version) / "gtk.css"
        live_dark = gtk_config_path(version) / "gtk-dark.css"
        checks[f"gtk{version}_loader"] = {"ok": light_loader.is_file() and dark_loader.is_file() and live_light.is_symlink() and Path(os.readlink(live_light)) == light_loader and live_dark.is_symlink() and Path(os.readlink(live_dark)) == dark_loader, "path": str(gtk_config_path(version)), "expected": f"gtk.css -> {light_loader}; gtk-dark.css -> {dark_loader}"}
        metadata_path = root / "current/gtk/metadata.json"
        if metadata_path.is_file():
            try:
                metadata = _gtk_metadata(root)
                expected_css = root / f"current/gtk/gtk-{version}.0/gtk.css" if metadata["generated_css"] else gtk_source_path(version, "blox-theme-empty.css")
            except RuntimeFailure:
                expected_css = root / f"current/gtk/gtk-{version}.0/gtk.css"
            settings = gtk_config_path(version) / "settings.ini"
            css = gtk_config_path(version) / "blox-theme.css"
            dark_css = gtk_config_path(version) / "blox-theme-dark.css"
            expected_settings = root / f"current/gtk/gtk-{version}.0/settings.ini"
            checks[f"gtk{version}_generated_links"] = {
                "ok": settings.is_symlink() and os.readlink(settings) == str(expected_settings) and css.is_symlink() and os.readlink(css) == str(expected_css) and dark_css.is_symlink() and os.readlink(dark_css) == str(expected_css),
                "path": str(gtk_config_path(version)),
                "expected": f"settings.ini -> {expected_settings}; generated CSS links -> {expected_css}",
            }
    return checks


def _reload_quickshell(mode: str, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]]) -> str | None:
    function = "reset" if mode == "reset" else "reload"
    command = ["quickshell", "ipc", "--path", str(quickshell_config_path()), "call", "theme", function]
    result = run_command(command)
    if result.returncode != 0:
        return f"Quickshell reload failed; run: {_command_text(command)}"
    return None


def _reload_vicinae(mode: str, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]]) -> str | None:
    theme_id = "blox-panel" if mode == "reset" else "blox-generated"
    command = ["vicinae", "theme", "set", theme_id]
    result = run_command(command)
    if result.returncode != 0:
        return f"Vicinae reload failed; run: {_command_text(command)}"
    return None


def _reload_wallpaper(root: Path, mode: str, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]]) -> str | None:
    source = root / "current/hypr/wallpaper.json"
    if mode == "reset":
        source = repository_root() / "themes/themes/blox-panel.json"
        try:
            data = json.loads(source.read_text(encoding="utf-8"))["wallpaper"]
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
            return f"Wallpaper reset metadata is invalid: {error}"
    else:
        try:
            data = json.loads(source.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            return f"Wallpaper metadata is invalid: {error}"
    wallpaper = str(Path(data["path"]).expanduser())
    command = ["hyprctl", "hyprpaper", "wallpaper", f",{wallpaper},{data['fit']}"]
    result = run_command(command)
    if result.returncode != 0:
        return f"Hyprpaper reload failed; run: {_command_text(command)}"
    return None


def _kitty_sockets() -> list[Path]:
    return sorted(path for path in Path("/tmp").glob("kitty-tabs-recover-*") if path.is_socket())


def _reload_kitty(run_command: Callable[[list[str]], subprocess.CompletedProcess[str]]) -> list[str]:
    sockets = _kitty_sockets()
    if not sockets:
        return ["Kitty is not running; new windows will read the generated theme"]
    warnings = []
    for socket in sockets:
        command = ["kitty", "@", "--to", f"unix:{socket}", "load-config"]
        if run_command(command).returncode != 0:
            warnings.append(f"Kitty reload failed; run: {_command_text(command)}")
    return warnings


def _reload_gtk(root: Path, mode: str, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]]) -> list[str]:
    if mode == "reset":
        source = repository_root() / "themes/themes/blox-panel.json"
        try:
            theme = json.loads(source.read_text(encoding="utf-8"))
            metadata = {"base_theme": theme["gtk"]["base_theme"], "font": f"{theme['fonts']['ui']} {theme['fonts']['gtk_size']}", "icon_theme": theme["icons"]["theme"], "variant": theme["variant"]}
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
            return [f"GTK reset metadata is invalid: {error}"]
    else:
        try:
            generated = _gtk_metadata(root)
            settings = (root / "current/gtk/gtk-4.0/settings.ini").read_text(encoding="utf-8")
            values = dict(line.split("=", 1) for line in settings.splitlines() if "=" in line)
            metadata = {"base_theme": generated["base_theme"], "font": values["gtk-font-name"], "icon_theme": values["gtk-icon-theme-name"], "variant": "dark" if values["gtk-application-prefer-dark-theme"] == "1" else "light"}
        except (OSError, KeyError, ValueError, RuntimeFailure) as error:
            return [f"GTK settings metadata is invalid: {error}"]
    commands = (
        ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", metadata["base_theme"]],
        ["gsettings", "set", "org.gnome.desktop.interface", "font-name", metadata["font"]],
        ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", metadata["icon_theme"]],
        ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark" if metadata["variant"] == "dark" else "default"],
    )
    warnings = []
    for command in commands:
        if run_command(command).returncode != 0:
            warnings.append(f"GTK setting update failed; run: {_command_text(command)}")
    return warnings


def run_reload_actions(root: Path, targets: Iterable[str], mode: str = "reload", run_command: Callable[[list[str]], subprocess.CompletedProcess[str]] = _run) -> list[str]:
    warnings = []
    for target in targets:
        if target == "quickshell":
            warning = _reload_quickshell(mode, run_command)
            if warning:
                warnings.append(warning)
        elif target == "vicinae":
            warning = _reload_vicinae(mode, run_command)
            if warning:
                warnings.append(warning)
        elif target == "wallpaper":
            warning = _reload_wallpaper(root, mode, run_command)
            if warning:
                warnings.append(warning)
        elif target == "kitty":
            warnings.extend(_reload_kitty(run_command))
        elif target == "gtk":
            warnings.extend(_reload_gtk(root, mode, run_command))
    return warnings


def apply_theme(theme_path: Path, theme: dict[str, Any], targets: Iterable[str], run_command: Callable[[list[str]], subprocess.CompletedProcess[str]] = _run, renderer: Callable[[dict[str, Any]], tuple[dict[str, str], list[str]]] = render_theme) -> tuple[dict[str, Any], list[str]]:
    root = state_dir()
    selected = tuple(targets)
    unknown = sorted(set(selected) - set(TARGET_NAMES))
    if unknown:
        raise RuntimeFailure(f"unsupported Phase 2 target(s): {', '.join(unknown)}")
    if not selected:
        raise RuntimeFailure("at least one target is required")
    verify_tracked_loaders(selected)
    with ApplicationLock(root):
        generations = root / "generations"
        generations.mkdir(parents=True, exist_ok=True)
        previous_record = current_generation(root)
        previous_path = previous_record[0] if previous_record else None
        previous_manifest = previous_record[1] if previous_record else None
        files, _ = renderer(theme)
        for target in selected:
            missing = [name for name in TARGET_REQUIRED_FILES[target] if name not in files]
            if missing:
                raise RuntimeFailure(f"renderer did not produce {target}: {', '.join(missing)}")

        generation_id = _new_generation_id()
        candidate = generations / f".candidate-{uuid.uuid4().hex}"
        final = generations / generation_id
        candidate.mkdir(mode=0o700)
        try:
            _copy_previous(previous_path, candidate)
            for target in selected:
                _remove_target(candidate, target)
                for name in TARGET_FILES[target]:
                    if name in files:
                        _write_text(candidate / name, files[name])
            sources = _target_sources(previous_manifest, selected, theme_path, theme)
            enabled = sorted(target for target, names in TARGET_FILES.items() if any((candidate / name).is_file() for name in names))
            sources = {target: sources[target] for target in enabled}
            manifest = {
                "schema_version": 1,
                "renderer_version": RENDERER_VERSION,
                "generation_id": generation_id,
                "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "operation": "apply",
                "source": str(theme_path.resolve()),
                "source_sha256": sha256_text(canonical_json(theme)),
                "theme_id": theme["id"],
                "enabled_targets": enabled,
                "target_sources": sources,
                "files": _manifest_files(candidate),
                "derived": {"ansi": json.loads(files["quickshell/theme.json"])["ansi"] if "quickshell/theme.json" in files else {}},
            }
            _write_text(candidate / "manifest.json", canonical_json(manifest))
            _fsync_directory(candidate)
            os.replace(candidate, final)
            _fsync_directory(generations)
            validate_generation(final)
            _switch_generation(root, final)
            try:
                sync_dynamic_loaders(root, enabled)
            except (OSError, RuntimeFailure):
                try:
                    if previous_path:
                        _switch_generation(root, previous_path)
                        try:
                            sync_dynamic_loaders(root, previous_manifest["enabled_targets"] if previous_manifest else ())
                        except (OSError, RuntimeFailure):
                            pass
                    else:
                        cleanup_managed_loaders(root)
                        (root / "current").unlink(missing_ok=True)
                        (root / "active.json").unlink(missing_ok=True)
                finally:
                    shutil.rmtree(final, ignore_errors=True)
                raise
            reload_warnings = run_reload_actions(root, selected, run_command=run_command)
            _prune_generations(root, final)
            return manifest, reload_warnings
        except Exception:
            shutil.rmtree(candidate, ignore_errors=True)
            raise


def reconcile(targets: Iterable[str] | None = None, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]] = _run) -> tuple[dict[str, Any], list[str]]:
    root = state_dir()
    with ApplicationLock(root):
        record = current_generation(root)
        if not record:
            raise RuntimeFailure("no active theme generation")
        _, manifest = record
        selected = tuple(targets) if targets is not None else tuple(manifest["enabled_targets"])
        unknown = sorted(set(selected) - set(manifest["enabled_targets"]))
        if unknown:
            raise RuntimeFailure(f"target(s) are not active: {', '.join(unknown)}")
        sync_dynamic_loaders(root, manifest["enabled_targets"])
        warnings = run_reload_actions(root, selected, run_command=run_command)
        return manifest, warnings


def rollback(generation_id: str | None = None, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]] = _run) -> tuple[dict[str, Any], list[str]]:
    root = state_dir()
    with ApplicationLock(root):
        current_record = current_generation(root)
        if not current_record:
            raise RuntimeFailure("no active theme generation")
        current_path = current_record[0]
        if generation_id:
            if not GENERATION_PATTERN.fullmatch(generation_id):
                raise RuntimeFailure(f"invalid generation ID: {generation_id}")
            target = root / "generations" / generation_id
        else:
            candidates = sorted((path for path in (root / "generations").iterdir() if path.is_dir() and GENERATION_PATTERN.fullmatch(path.name) and path != current_path), key=lambda item: item.stat().st_mtime_ns, reverse=True)
            if not candidates:
                raise RuntimeFailure("no previous generation is available")
            target = candidates[0]
        if target == current_path:
            raise RuntimeFailure("requested generation is already active")
        manifest = validate_generation(target)
        _switch_generation(root, target)
        try:
            sync_dynamic_loaders(root, manifest["enabled_targets"])
        except (OSError, RuntimeFailure):
            _switch_generation(root, current_path)
            try:
                sync_dynamic_loaders(root, current_record[1]["enabled_targets"])
            except (OSError, RuntimeFailure):
                pass
            raise
        warnings = run_reload_actions(root, manifest["enabled_targets"], run_command=run_command)
        return manifest, warnings


def reset_target(target: str, run_command: Callable[[list[str]], subprocess.CompletedProcess[str]] = _run) -> tuple[dict[str, Any], list[str]]:
    if target not in TARGET_NAMES:
        raise RuntimeFailure(f"unsupported Phase 2 target: {target}")
    root = state_dir()
    with ApplicationLock(root):
        record = current_generation(root)
        if not record:
            raise RuntimeFailure("no active theme generation")
        previous, previous_manifest = record
        if target not in previous_manifest["enabled_targets"]:
            raise RuntimeFailure(f"target is not active: {target}")
        generations = root / "generations"
        generation_id = _new_generation_id()
        candidate = generations / f".candidate-{uuid.uuid4().hex}"
        final = generations / generation_id
        candidate.mkdir(mode=0o700)
        try:
            _copy_previous(previous, candidate)
            _remove_target(candidate, target)
            enabled = sorted(item for item in previous_manifest["enabled_targets"] if item != target)
            sources = {item: value for item, value in previous_manifest["target_sources"].items() if item != target}
            manifest = {
                "schema_version": 1,
                "renderer_version": RENDERER_VERSION,
                "generation_id": generation_id,
                "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "operation": f"reset-target:{target}",
                "source": previous_manifest["source"],
                "source_sha256": previous_manifest["source_sha256"],
                "theme_id": previous_manifest["theme_id"],
                "enabled_targets": enabled,
                "target_sources": sources,
                "files": _manifest_files(candidate),
                "derived": previous_manifest["derived"],
            }
            _write_text(candidate / "manifest.json", canonical_json(manifest))
            _fsync_directory(candidate)
            os.replace(candidate, final)
            validate_generation(final)
            _switch_generation(root, final)
            try:
                sync_dynamic_loaders(root, enabled)
            except (OSError, RuntimeFailure):
                try:
                    _switch_generation(root, previous)
                    try:
                        sync_dynamic_loaders(root, previous_manifest["enabled_targets"])
                    except (OSError, RuntimeFailure):
                        pass
                finally:
                    shutil.rmtree(final, ignore_errors=True)
                raise
            warnings = run_reload_actions(root, (target,), mode="reset", run_command=run_command)
            _prune_generations(root, final)
            return manifest, warnings
        except Exception:
            shutil.rmtree(candidate, ignore_errors=True)
            raise
