#!/usr/bin/env python3
"""Small public CLI adapter for the supervised Blox shell action owner."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_ROOT = Path(__file__).resolve().parent
IPC = SCRIPT_ROOT / "ipc.sh"
EXIT_OK = 0
EXIT_USAGE = 2
EXIT_UNAVAILABLE = 3
EXIT_DENIED = 4
EXIT_CONFLICT = 5
EXIT_INVALID_DATA = 6
EXIT_INTERNAL = 1


def result(ok: bool, code: str, message: str = "", data: Any = None) -> dict[str, Any]:
    return {
        "version": 1,
        "ok": ok,
        "code": code,
        "message": message,
        "data": data,
    }


def exit_code(action: dict[str, Any]) -> int:
    if action.get("ok") is True:
        return EXIT_OK
    return {
        "permission-denied": EXIT_DENIED,
        "conflict": EXIT_CONFLICT,
        "invalid-data": EXIT_INVALID_DATA,
        "unavailable": EXIT_UNAVAILABLE,
    }.get(action.get("code"), EXIT_INTERNAL)


def call_owner() -> dict[str, Any]:
    try:
        completed = subprocess.run(
            [str(IPC), "blox", "status"],
            cwd=SCRIPT_ROOT,
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return result(False, "unavailable", "The Blox shell is not running.")

    if completed.returncode != 0:
        return result(False, "unavailable", "The Blox shell is not running.")

    try:
        action = json.loads(completed.stdout.strip())
    except json.JSONDecodeError:
        return result(False, "invalid-data", "The Blox shell returned invalid status data.")

    if not isinstance(action, dict):
        return result(False, "invalid-data", "The Blox shell returned a non-object status result.")
    required = {"version", "ok", "code", "message", "data"}
    if set(action) != required or action["version"] != 1 or not isinstance(action["ok"], bool):
        return result(False, "invalid-data", "The Blox shell returned an invalid action result.")
    return action


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="bloxctl")
    parser.add_argument("group", choices=["status", "doctor", "settings", "theme", "lifecycle"])
    parser.add_argument("command", nargs="*")
    parser.add_argument("--json", action="store_true", dest="as_json")
    return parser


def run(argv: list[str]) -> tuple[int, dict[str, Any], bool]:
    try:
        args = build_parser().parse_args(argv)
    except SystemExit as error:
        return int(error.code), result(False, "usage", "Use: bloxctl status [--json]."), "--json" in argv

    if args.group == "status" and not args.command:
        action = call_owner()
        return exit_code(action), action, args.as_json

    if args.group != "status":
        action = result(False, "unavailable", f"The {args.group} commands belong to a later phase.")
        return EXIT_UNAVAILABLE, action, args.as_json

    action = result(False, "usage", "Use: bloxctl status [--json].")
    return EXIT_USAGE, action, args.as_json


def main(argv: list[str] | None = None) -> int:
    code, action, as_json = run(sys.argv[1:] if argv is None else argv)
    if as_json:
        print(json.dumps(action, separators=(",", ":"), sort_keys=True))
    elif action["ok"]:
        print(json.dumps(action["data"], indent=2, sort_keys=True))
    else:
        print(action["message"], file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
