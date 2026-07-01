from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


THEMES = Path(__file__).resolve().parents[1]
REPOSITORY = THEMES.parent
sys.path.insert(0, str(THEMES / "lib"))

from blox_theme.core import load_theme, render_theme
from blox_theme.runtime import ApplicationLock, LockContended, RuntimeFailure, TARGET_FILES, TARGET_NAMES, apply_theme, current_generation, kitty_theme_link, reconcile, reset_target, rollback, validate_generation, vicinae_theme_link


class FakeCommands:
    def __init__(self, returncode: int = 0) -> None:
        self.returncode = returncode
        self.commands: list[list[str]] = []

    def __call__(self, command: list[str]) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        return subprocess.CompletedProcess(command, self.returncode, "", "failed" if self.returncode else "")


class RuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.environment = mock.patch.dict(os.environ, {
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "data"),
        })
        self.environment.start()
        quickshell_loader = self.root / "config/quickshell/blox/shared/Theme.qml"
        quickshell_loader.parent.mkdir(parents=True)
        quickshell_loader.write_text("watchChanges: true\nfunction loadJson() {}\n", encoding="utf-8")
        kitty_config = self.root / "config/kitty/kitty.conf"
        kitty_config.parent.mkdir(parents=True)
        kitty_config.write_text("globinclude blox-theme.conf\n", encoding="utf-8")
        self.canonical_path, self.canonical = load_theme("blox-panel")
        self.alternate_path = THEMES / "tests/fixtures/phase2-alternate.json"
        self.alternate = json.loads(self.alternate_path.read_text(encoding="utf-8"))

    def tearDown(self) -> None:
        self.environment.stop()
        self.temporary.cleanup()

    @property
    def state(self) -> Path:
        return Path(os.environ["XDG_STATE_HOME"]) / "blox-theme"

    def apply_canonical(self, runner: FakeCommands | None = None) -> tuple[dict, list[str]]:
        return apply_theme(self.canonical_path, self.canonical, TARGET_NAMES, run_command=runner or FakeCommands())

    def test_initial_apply_creates_valid_atomic_layout_and_loaders(self) -> None:
        runner = FakeCommands()
        manifest, warnings = self.apply_canonical(runner)
        self.assertEqual([], warnings)
        self.assertTrue((self.state / "current").is_symlink())
        self.assertEqual("current/manifest.json", os.readlink(self.state / "active.json"))
        generation, checked = current_generation(self.state)
        self.assertEqual(manifest, checked)
        self.assertEqual(set(TARGET_NAMES), set(manifest["enabled_targets"]))
        self.assertTrue(vicinae_theme_link().is_symlink())
        self.assertEqual(self.state / "current/vicinae/theme.toml", Path(os.readlink(vicinae_theme_link())))
        self.assertTrue((self.root / "config/kitty/blox-theme.conf").is_symlink())
        self.assertEqual([], list((self.state / "generations").glob(".candidate-*")))
        self.assertEqual(generation, (self.state / "current").resolve())
        flattened = [part for command in runner.commands for part in command]
        for executable in ("quickshell", "vicinae", "hyprctl", "kitty"):
            self.assertIn(executable, flattened)

    def test_partial_apply_carries_unselected_targets_byte_for_byte(self) -> None:
        self.apply_canonical()
        before_path, before_manifest = current_generation(self.state)
        before = {name: (before_path / name).read_bytes() for name in before_manifest["files"]}
        manifest, _ = apply_theme(self.alternate_path, self.alternate, ("quickshell",), run_command=FakeCommands())
        after_path, _ = current_generation(self.state)
        self.assertNotEqual(before["quickshell/theme.json"], (after_path / "quickshell/theme.json").read_bytes())
        for name in ("vicinae/theme.toml", "kitty/theme.conf", "hypr/wallpaper.json"):
            self.assertEqual(before[name], (after_path / name).read_bytes(), name)
        self.assertEqual("phase2-alternate", manifest["target_sources"]["quickshell"]["theme_id"])
        self.assertEqual("blox-panel", manifest["target_sources"]["kitty"]["theme_id"])

    def test_alternate_theme_changes_all_four_targets(self) -> None:
        self.apply_canonical()
        before_path, before_manifest = current_generation(self.state)
        before = {name: (before_path / name).read_bytes() for name in before_manifest["files"]}
        apply_theme(self.alternate_path, self.alternate, TARGET_NAMES, run_command=FakeCommands())
        after_path, after_manifest = current_generation(self.state)
        self.assertEqual(set(before), set(after_manifest["files"]))
        for name in before:
            self.assertNotEqual(before[name], (after_path / name).read_bytes(), name)

    def test_render_failure_cannot_expose_partial_generation(self) -> None:
        self.apply_canonical()
        before = os.readlink(self.state / "current")

        def fail_renderer(theme: dict) -> tuple[dict[str, str], list[str]]:
            raise RuntimeFailure("injected render failure")

        with self.assertRaisesRegex(RuntimeFailure, "injected"):
            apply_theme(self.alternate_path, self.alternate, TARGET_NAMES, run_command=FakeCommands(), renderer=fail_renderer)
        self.assertEqual(before, os.readlink(self.state / "current"))
        self.assertEqual([], list((self.state / "generations").glob(".candidate-*")))

    def test_corrupt_active_generation_blocks_carry_forward(self) -> None:
        self.apply_canonical()
        active, _ = current_generation(self.state)
        (active / "kitty/theme.conf").write_text("tampered\n", encoding="utf-8")
        before = os.readlink(self.state / "current")
        with self.assertRaisesRegex(RuntimeFailure, "digest mismatch"):
            apply_theme(self.alternate_path, self.alternate, ("quickshell",), run_command=FakeCommands())
        self.assertEqual(before, os.readlink(self.state / "current"))

    def test_loader_conflict_rolls_back_activation(self) -> None:
        link = vicinae_theme_link()
        link.parent.mkdir(parents=True)
        link.write_text("owned", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeFailure, "conflicting"):
            self.apply_canonical()
        self.assertFalse((self.state / "current").exists())
        self.assertFalse((self.state / "active.json").exists())
        self.assertEqual("owned", link.read_text(encoding="utf-8"))

    def test_partial_loader_installation_is_cleaned_up(self) -> None:
        link = kitty_theme_link()
        link.write_text("owned", encoding="utf-8")
        with self.assertRaisesRegex(RuntimeFailure, "conflicting Kitty"):
            self.apply_canonical()
        self.assertFalse(vicinae_theme_link().exists())
        self.assertEqual("owned", link.read_text(encoding="utf-8"))
        self.assertFalse((self.state / "current").exists())

    def test_missing_tracked_loader_blocks_apply_before_state_mutation(self) -> None:
        (self.root / "config/quickshell/blox/shared/Theme.qml").unlink()
        with self.assertRaisesRegex(RuntimeFailure, "tracked theme loader"):
            apply_theme(self.canonical_path, self.canonical, ("quickshell",), run_command=FakeCommands())
        self.assertFalse(self.state.exists())

    def test_reload_failure_keeps_valid_files_active_and_returns_recovery(self) -> None:
        manifest, warnings = self.apply_canonical(FakeCommands(returncode=1))
        self.assertEqual(manifest, current_generation(self.state)[1])
        self.assertTrue(any("run:" in warning for warning in warnings))

    def test_reconcile_is_idempotent_and_does_not_render(self) -> None:
        self.apply_canonical()
        before = os.readlink(self.state / "current")
        first_runner = FakeCommands()
        second_runner = FakeCommands()
        first, first_warnings = reconcile(run_command=first_runner)
        second, second_warnings = reconcile(run_command=second_runner)
        self.assertEqual(first, second)
        self.assertEqual([], first_warnings + second_warnings)
        self.assertEqual(before, os.readlink(self.state / "current"))
        self.assertEqual(first_runner.commands, second_runner.commands)

    def test_rollback_restores_files_and_runs_reload_actions(self) -> None:
        first, _ = self.apply_canonical()
        first_path = (self.state / "current").resolve()
        first_quickshell = (first_path / "quickshell/theme.json").read_bytes()
        apply_theme(self.alternate_path, self.alternate, TARGET_NAMES, run_command=FakeCommands())
        runner = FakeCommands()
        restored, warnings = rollback(first["generation_id"], run_command=runner)
        self.assertEqual([], warnings)
        self.assertEqual(first["generation_id"], restored["generation_id"])
        self.assertEqual(first_quickshell, ((self.state / "current").resolve() / "quickshell/theme.json").read_bytes())
        self.assertTrue(runner.commands)

    def test_reset_target_removes_only_that_target_and_runs_reset(self) -> None:
        self.apply_canonical()
        runner = FakeCommands()
        manifest, warnings = reset_target("quickshell", run_command=runner)
        self.assertEqual([], warnings)
        active = (self.state / "current").resolve()
        self.assertFalse((active / "quickshell/theme.json").exists())
        self.assertNotIn("quickshell", manifest["enabled_targets"])
        self.assertTrue((active / "kitty/theme.conf").is_file())
        self.assertIn("reset", runner.commands[0])

    def test_every_target_reset_path_is_safe(self) -> None:
        for target in TARGET_NAMES:
            with self.subTest(target=target):
                if self.state.exists():
                    shutil.rmtree(self.state)
                for link in (vicinae_theme_link(), kitty_theme_link()):
                    if link.is_symlink():
                        link.unlink()
                self.apply_canonical()
                runner = FakeCommands()
                manifest, warnings = reset_target(target, run_command=runner)
                self.assertEqual([], warnings)
                active = (self.state / "current").resolve()
                for name in TARGET_FILES[target]:
                    self.assertFalse((active / name).exists())
                self.assertNotIn(target, manifest["enabled_targets"])
                if target == "vicinae":
                    self.assertFalse(vicinae_theme_link().exists())
                    self.assertIn("blox-panel", runner.commands[0])
                if target == "kitty":
                    self.assertFalse(kitty_theme_link().exists())

    def test_history_retains_current_plus_five_previous_generations(self) -> None:
        for index in range(8):
            theme = self.canonical if index % 2 == 0 else self.alternate
            path = self.canonical_path if index % 2 == 0 else self.alternate_path
            apply_theme(path, theme, TARGET_NAMES, run_command=FakeCommands())
        generations = [path for path in (self.state / "generations").iterdir() if path.is_dir()]
        self.assertEqual(6, len(generations))
        self.assertIn((self.state / "current").resolve(), generations)

    def test_lock_contention_is_reported_without_mutation(self) -> None:
        with ApplicationLock(self.state):
            with self.assertRaises(LockContended):
                self.apply_canonical()
        self.assertFalse((self.state / "current").exists())

    def test_manifest_tampering_and_escaping_current_link_are_rejected(self) -> None:
        self.apply_canonical()
        active, _ = current_generation(self.state)
        manifest_path = active / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["unexpected"] = True
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(RuntimeFailure, "structure"):
            validate_generation(active)
        (self.state / "current").unlink()
        (self.state / "current").symlink_to(self.root)
        with self.assertRaisesRegex(RuntimeFailure, "escapes"):
            current_generation(self.state)

    def test_invalid_active_manifest_link_is_rejected(self) -> None:
        self.apply_canonical()
        (self.state / "active.json").unlink()
        (self.state / "active.json").symlink_to("wrong.json")
        with self.assertRaisesRegex(RuntimeFailure, "active manifest link"):
            current_generation(self.state)

    def test_invalid_targets_are_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeFailure, "unsupported"):
            apply_theme(self.canonical_path, self.canonical, ("unknown",), run_command=FakeCommands())

    def test_reconcile_and_rollback_reject_invalid_requests(self) -> None:
        first, _ = self.apply_canonical()
        with self.assertRaisesRegex(RuntimeFailure, "not active"):
            reconcile(("unknown",), run_command=FakeCommands())
        with self.assertRaisesRegex(RuntimeFailure, "already active"):
            rollback(first["generation_id"], run_command=FakeCommands())
        with self.assertRaisesRegex(RuntimeFailure, "invalid generation ID"):
            rollback("../escape", run_command=FakeCommands())


class RuntimeCliTests(unittest.TestCase):
    def test_cli_apply_reconcile_reset_and_rollback_envelopes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            for name in ("quickshell", "vicinae", "hyprctl", "kitty"):
                executable = fake_bin / name
                executable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                executable.chmod(0o755)
            environment = os.environ.copy()
            environment.update({
                "XDG_STATE_HOME": str(root / "state"),
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_DATA_HOME": str(root / "data"),
                "PATH": f"{fake_bin}:{environment['PATH']}",
            })
            quickshell_loader = root / "config/quickshell/blox/shared/Theme.qml"
            quickshell_loader.parent.mkdir(parents=True)
            quickshell_loader.write_text("watchChanges: true\nfunction loadJson() {}\n", encoding="utf-8")
            kitty_config = root / "config/kitty/kitty.conf"
            kitty_config.parent.mkdir(parents=True)
            kitty_config.write_text("globinclude blox-theme.conf\n", encoding="utf-8")

            def invoke(*arguments: str) -> tuple[int, dict]:
                completed = subprocess.run([str(THEMES / "bin/themectl"), *arguments, "--json"], cwd=REPOSITORY, env=environment, check=False, capture_output=True, text=True)
                return completed.returncode, json.loads(completed.stdout)

            apply_code, applied = invoke("apply", "blox-panel", "--targets", "quickshell,wallpaper")
            self.assertEqual(0, apply_code)
            self.assertTrue(applied["ok"])
            first = applied["data"]["generation"]
            reconcile_code, reconciled = invoke("reconcile")
            self.assertEqual(0, reconcile_code)
            self.assertEqual(first, reconciled["data"]["generation"])
            reset_code, reset = invoke("reset-target", "quickshell")
            self.assertEqual(0, reset_code)
            self.assertNotIn("quickshell", reset["data"]["active_targets"])
            rollback_code, rolled_back = invoke("rollback", first)
            self.assertEqual(0, rollback_code)
            self.assertIn("quickshell", rolled_back["data"]["active_targets"])


if __name__ == "__main__":
    unittest.main()
