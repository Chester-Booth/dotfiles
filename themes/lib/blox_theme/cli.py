from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Any

from . import API_VERSION
from .core import (
    EXIT_DEPENDENCY,
    EXIT_OK,
    EXIT_RENDER,
    EXIT_VALIDATION,
    canonical_json,
    contrast_ratio,
    dependency_checks,
    derive_ansi,
    list_themes,
    load_theme,
    render_manifest,
    render_theme,
    rendered_diff,
    repository_root,
    state_dir,
    themes_dir,
    validate_theme,
    write_render,
)


def envelope(command: str, data: Any = None, errors: list[str] | None = None, warnings: list[str] | None = None) -> dict[str, Any]:
    errors = errors or []
    warnings = warnings or []
    return {"api_version": API_VERSION, "command": command, "ok": not errors, "status": "error" if errors else "warning" if warnings else "ok", "data": data, "warnings": warnings, "errors": errors}


def emit(result: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(canonical_json(result), end="")
        return
    for error in result["errors"]:
        print(f"error: {error}", file=sys.stderr)
    for warning in result["warnings"]:
        print(f"warning: {warning}", file=sys.stderr)
    data = result["data"]
    if isinstance(data, str):
        print(data)
    elif data is not None:
        print(canonical_json(data), end="")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="themectl", description="Validate and render repository-owned themes without changing live configuration.")
    subcommands = root.add_subparsers(dest="command", required=True)

    list_parser = subcommands.add_parser("list", help="list source themes")
    list_parser.add_argument("--json", action="store_true")
    for name in ("show", "validate", "preview", "diff"):
        child = subcommands.add_parser(name)
        child.add_argument("theme")
        child.add_argument("--json", action="store_true")
    render = subcommands.add_parser("render")
    render.add_argument("theme")
    render.add_argument("--output", type=Path)
    render.add_argument("--json", action="store_true")
    doctor = subcommands.add_parser("doctor")
    doctor.add_argument("--json", action="store_true")
    return root


def checked_theme(command: str, reference: str, check_dependencies: bool = True) -> tuple[Path | None, dict[str, Any] | None, dict[str, Any] | None, int]:
    try:
        path, theme = load_theme(reference)
    except FileNotFoundError as error:
        return None, None, envelope(command, errors=[str(error)]), EXIT_DEPENDENCY
    except (OSError, json.JSONDecodeError, ValueError) as error:
        return None, None, envelope(command, errors=[str(error)]), EXIT_VALIDATION
    checked = validate_theme(theme, check_dependencies=check_dependencies)
    if checked.errors:
        return path, theme, envelope(command, errors=checked.errors, warnings=checked.warnings), EXIT_VALIDATION
    return path, theme, None, EXIT_OK


def run(args: argparse.Namespace) -> tuple[dict[str, Any], int]:
    command = args.command
    if command == "list":
        themes = list_themes()
        if args.json:
            return envelope(command, themes), EXIT_OK
        summary = "\n".join(f"{item['id']:<24} {item['variant'] or '-':<6} {item['name']}" for item in themes)
        return envelope(command, summary), EXIT_OK

    if command == "doctor":
        checks = {
            "repository": {"ok": repository_root().is_dir(), "path": str(repository_root())},
            "schema": {"ok": (themes_dir() / "schema/theme.schema.json").is_file()},
            "theme_library": {"ok": (themes_dir() / "themes").is_dir()},
            "jsonschema": {"ok": False, "required": False},
            "fc_match": {"ok": shutil.which("fc-match") is not None},
            "state_directory": {"ok": state_dir().is_dir(), "path": str(state_dir()), "required": False},
            "active_generation": {"ok": (state_dir() / "current").exists(), "required": False},
        }
        try:
            import jsonschema  # noqa: F401

            checks["jsonschema"]["ok"] = True
        except ImportError:
            pass
        warnings = ["jsonschema is not installed; using the bundled strict validator"] if not checks["jsonschema"]["ok"] else []
        if not checks["state_directory"]["ok"]:
            warnings.append("theme state directory does not exist yet; Phase 2 apply will create it")
        errors = [name for name, check in checks.items() if not check["ok"] and check.get("required", True)]
        return envelope(command, checks, errors=[f"failed check: {name}" for name in errors], warnings=warnings), EXIT_DEPENDENCY if errors else EXIT_OK

    path, theme, failure, code = checked_theme(command, args.theme, check_dependencies=command != "show")
    if failure:
        return failure, code
    assert path is not None and theme is not None

    checked = validate_theme(theme, check_dependencies=command != "show")
    if command == "show":
        return envelope(command, theme), EXIT_OK
    if command == "validate":
        data = {"id": theme["id"], "path": str(path), "valid": True}
        return envelope(command, data, warnings=checked.warnings), EXIT_OK

    try:
        files, render_warnings = render_theme(theme)
        manifest = render_manifest(path, theme, files)
    except (KeyError, TypeError, ValueError) as error:
        return envelope(command, errors=[f"render failed: {error}"]), EXIT_RENDER
    warnings = checked.warnings + render_warnings
    if command == "render":
        if args.output:
            try:
                write_render(args.output, files, manifest)
            except (OSError, ValueError) as error:
                return envelope(command, errors=[f"render failed: {error}"]), EXIT_RENDER
        data = {"theme_id": theme["id"], "output": str(args.output.expanduser().resolve()) if args.output else None, "manifest": manifest}
        return envelope(command, data, warnings=warnings), EXIT_OK
    if command == "diff":
        return envelope(command, {"theme_id": theme["id"], "state_directory": str(state_dir()), "changes": rendered_diff(files)}, warnings=warnings), EXIT_OK

    colours = theme["colours"]
    pairs = {}
    for foreground, background in (("foreground", "background"), ("foreground", "surface"), ("muted", "background"), ("selection_foreground", "selection_background"), ("accent", "background")):
        pairs[f"{foreground}/{background}"] = round(contrast_ratio(colours[foreground], colours[background]), 2)
    data = {
        "id": theme["id"], "name": theme["name"], "variant": theme["variant"],
        "colours": colours, "ansi": derive_ansi(theme), "fonts": theme["fonts"],
        "contrast": pairs, "enabled_targets": [name for name, enabled in theme["targets"].items() if enabled],
        "rendered_files": list(files),
    }
    return envelope(command, data, warnings=warnings), EXIT_OK


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    result, code = run(args)
    emit(result, args.json)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
