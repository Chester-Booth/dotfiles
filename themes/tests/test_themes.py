from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest import mock


THEMES = Path(__file__).resolve().parents[1]
REPOSITORY = THEMES.parent
sys.path.insert(0, str(THEMES / "lib"))

from blox_theme.core import dependency_checks, derive_ansi, load_theme, render_manifest, render_theme, schema_errors, validate_theme


def run_cli(*arguments: str, environment: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(THEMES / "bin/themectl"), *arguments], cwd=REPOSITORY, env=environment, capture_output=True, text=True, check=False)


class ThemeSchemaTests(unittest.TestCase):
    def test_canonical_theme_is_valid(self) -> None:
        _, theme = load_theme("blox-panel")
        result = validate_theme(theme)
        self.assertEqual([], result.errors)

    def test_invalid_fixtures_fail_schema_validation(self) -> None:
        fixtures = THEMES / "tests/fixtures"
        for fixture in (fixtures / "invalid-colour.json", fixtures / "unknown-field.json"):
            with self.subTest(fixture=fixture.name):
                theme = json.loads(fixture.read_text(encoding="utf-8"))
                self.assertTrue(schema_errors(theme))

    def test_invalid_fixtures_have_documented_exit_code(self) -> None:
        fixtures = THEMES / "tests/fixtures"
        for fixture in (fixtures / "invalid-colour.json", fixtures / "unknown-field.json"):
            with self.subTest(fixture=fixture.name):
                completed = run_cli("validate", str(fixture), "--json")
                self.assertEqual(3, completed.returncode)
                self.assertEqual("error", json.loads(completed.stdout)["status"])

    def test_contrast_failure_is_rejected(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["colours"]["foreground"] = theme["colours"]["background"]
        result = validate_theme(theme, check_dependencies=False)
        self.assertTrue(any("contrast" in error for error in result.errors))

    def test_gtk_override_source_requires_values(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["gtk"]["colour_source"] = "override"
        result = validate_theme(theme, check_dependencies=False)
        self.assertTrue(any("overrides.gtk" in error for error in result.errors))
        theme["overrides"] = {"gtk": {"accent": "#abcdef"}}
        self.assertFalse(any("overrides.gtk" in error for error in validate_theme(theme, check_dependencies=False).errors))

    def test_low_contrast_gtk_override_is_rejected(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["overrides"] = {"gtk": {"foreground": theme["colours"]["background"]}}
        self.assertTrue(any("GTK override" in error for error in validate_theme(theme, check_dependencies=False).errors))

    def test_schema_boundaries_and_unknown_nested_fields(self) -> None:
        _, source = load_theme("blox-panel")
        mutations = {
            "future schema": lambda theme: theme.update(schema_version=2),
            "invalid id": lambda theme: theme.update(id="Invalid ID"),
            "unknown target": lambda theme: theme["targets"].update(unknown=True),
            "missing target": lambda theme: theme["targets"].pop("kitty"),
            "small font": lambda theme: theme["fonts"].update(terminal_size=5),
            "duplicate cursor size": lambda theme: theme["cursor"].update(sizes=[24, 24]),
            "large cursor": lambda theme: theme["cursor"].update(sizes=[97]),
            "unknown override": lambda theme: theme.update(overrides={"ansi": {"color16": "#ffffff"}}),
            "short generator digest": lambda theme: theme.update(generator={"backend": "test", "version": "1", "wallpaper_sha256": "abc"}),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                theme = copy.deepcopy(source)
                mutate(theme)
                self.assertTrue(schema_errors(theme))

    def test_dependency_checks_respect_target_enablement(self) -> None:
        _, source = load_theme("blox-panel")
        theme = copy.deepcopy(source)
        for target in theme["targets"]:
            theme["targets"][target] = False
        theme["wallpaper"]["path"] = "/missing"
        theme["gtk"]["base_theme"] = "Missing-GTK"
        theme["icons"]["theme"] = "Missing-Icons"
        theme["cursor"].update(mode="installed", base="Missing-Cursor")
        with mock.patch("blox_theme.cursor.toolchain_check", return_value={"ok": False, "recovery": "themectl setup cursor --yes"}):
            result = dependency_checks(theme)
        self.assertEqual([], result.errors)
        self.assertEqual([], result.warnings)

        expected = {"wallpaper": "wallpaper", "gtk": "GTK base theme", "vicinae": "icon theme", "cursor": "cursor base"}
        for target, message in expected.items():
            with self.subTest(target=target):
                candidate = copy.deepcopy(theme)
                candidate["targets"][target] = True
                self.assertTrue(any(message in error for error in dependency_checks(candidate).errors))

    def test_missing_generated_cursor_is_a_warning(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["cursor"]["base"] = "Definitely-Missing-Cursor"
        with mock.patch("blox_theme.cursor.toolchain_check", return_value={"ok": False, "recovery": "themectl setup cursor --yes"}):
            result = dependency_checks(theme)
        self.assertFalse(any("cursor base" in error for error in result.errors))
        self.assertTrue(any("cursor toolchain" in warning for warning in result.warnings))

    def test_canonical_palette_matches_live_quickshell_fallback(self) -> None:
        _, theme = load_theme("blox-panel")
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/Theme.qml").read_text(encoding="utf-8")
        mapping = {"background": "background", "surface": "surface", "surfaceAlt": "surface_alt", "foreground": "foreground", "muted": "muted", "red": "danger", "green": "success", "yellow": "warning", "blue": "info", "mauve": "mauve", "teal": "teal"}
        for qml_name, theme_name in mapping.items():
            match = re.search(rf'property color {qml_name}: "(#[0-9a-fA-F]{{6}})"', qml)
            self.assertIsNotNone(match, qml_name)
            self.assertEqual(theme["colours"][theme_name].lower(), match.group(1).lower())
        self.assertIn(f'property string fontFamily: "{theme["fonts"]["panel"]}"', qml)


class RendererTests(unittest.TestCase):
    def setUp(self) -> None:
        self.path, self.theme = load_theme("blox-panel")

    def test_render_matches_golden_hashes(self) -> None:
        files, _ = render_theme(self.theme)
        actual = {name: hashlib.sha256(content.encode()).hexdigest() for name, content in files.items()}
        expected = json.loads((THEMES / "tests/golden/blox-panel.sha256.json").read_text(encoding="utf-8"))
        self.assertEqual(expected, actual)

    def test_render_is_deterministic(self) -> None:
        first_files, first_warnings = render_theme(self.theme)
        second_files, second_warnings = render_theme(self.theme)
        self.assertEqual(first_files, second_files)
        self.assertEqual(first_warnings, second_warnings)
        self.assertEqual(render_manifest(self.path, self.theme, first_files), render_manifest(self.path, self.theme, second_files))

    def test_rendered_formats_are_valid_and_complete(self) -> None:
        files, _ = render_theme(self.theme)
        quickshell = json.loads(files["quickshell/theme.json"])
        self.assertEqual(self.theme["colours"], quickshell["colours"])
        self.assertEqual(derive_ansi(self.theme), quickshell["ansi"])
        vicinae = tomllib.loads(files["vicinae/theme.toml"])
        self.assertEqual(self.theme["colours"]["accent"], vicinae["colors"]["core"]["accent"])
        wallpaper = json.loads(files["hypr/wallpaper.json"])
        self.assertEqual(self.theme["wallpaper"], {"path": wallpaper["path"], "fit": wallpaper["fit"]})
        for name, colour in derive_ansi(self.theme).items():
            self.assertIn(f"{name} {colour}", files["kitty/theme.conf"])
        self.assertIn("inactive_tab_background #242424", files["kitty/theme.conf"])
        self.assertIn("tab_bar_background #242424", files["kitty/theme.conf"])
        phase7 = {
            "hyprland/theme.lua", "hyprlock/theme.conf", "btop/theme.theme",
            "micro/blox-theme.micro", "glow/style.json", "code/settings.json",
            "cursor-editor/settings.json", "stylus/blox-system.user.css",
            "powerlevel10k/theme.zsh",
        }
        self.assertTrue(phase7.issubset(files))
        self.assertEqual(self.theme["fonts"]["mono"], json.loads(files["code/settings.json"])["editor.fontFamily"])
        self.assertEqual(json.loads(files["code/settings.json"]), json.loads(files["cursor-editor/settings.json"]))
        self.assertIn("@-moz-document", files["stylus/blox-system.user.css"])
        self.assertIn('color-link default "#cdd6f4"', files["micro/blox-theme.micro"])
        self.assertNotIn('color-link default "#cdd6f4,#242424"', files["micro/blox-theme.micro"])

    def test_phase7_targets_are_isolated(self) -> None:
        target_files = {
            "hyprland": "hyprland/theme.lua", "hyprlock": "hyprlock/theme.conf",
            "btop": "btop/theme.theme", "micro": "micro/blox-theme.micro",
            "glow": "glow/style.json", "code": "code/settings.json",
            "cursor_editor": "cursor-editor/settings.json", "stylus": "stylus/blox-system.user.css",
            "powerlevel10k": "powerlevel10k/theme.zsh",
        }
        for target, expected in target_files.items():
            with self.subTest(target=target):
                theme = copy.deepcopy(self.theme)
                for key in theme["targets"]:
                    theme["targets"][key] = key == target
                files, _ = render_theme(theme)
                self.assertEqual([expected], list(files))

    def test_ansi_override_is_target_local(self) -> None:
        theme = copy.deepcopy(self.theme)
        theme["overrides"] = {"ansi": {"color1": "#010203"}}
        files, _ = render_theme(theme)
        self.assertEqual("#010203", json.loads(files["quickshell/theme.json"])["ansi"]["color1"])
        self.assertIn("color1 #010203", files["kitty/theme.conf"])
        self.assertEqual(self.theme["colours"], theme["colours"])
        self.assertNotIn("#010203", files["vicinae/theme.toml"])

    def test_generated_gtk_outputs_settings_css_and_limitations(self) -> None:
        files, _ = render_theme(self.theme)
        metadata = json.loads(files["gtk/metadata.json"])
        self.assertTrue(metadata["generated_css"])
        self.assertEqual("partial-user-css", metadata["libadwaita_support"])
        self.assertIn("gtk-theme-name=Graphite-Dark-compact", files["gtk/gtk-3.0/settings.ini"])
        self.assertIn("gtk-font-name=Google Sans 11", files["gtk/gtk-4.0/settings.ini"])
        self.assertIn("@define-color blox_accent #89b4fa;", files["gtk/gtk-3.0/gtk.css"])
        self.assertIn("switch:checked", files["gtk/gtk-4.0/gtk.css"])

    def test_installed_gtk_mode_emits_no_generated_css(self) -> None:
        theme = copy.deepcopy(self.theme)
        theme["gtk"].update(mode="installed", base_theme="Adwaita")
        files, _ = render_theme(theme)
        self.assertNotIn("gtk/gtk-3.0/gtk.css", files)
        self.assertNotIn("gtk/gtk-4.0/gtk.css", files)
        self.assertIn("gtk-theme-name=Adwaita", files["gtk/gtk-3.0/settings.ini"])
        self.assertFalse(json.loads(files["gtk/metadata.json"])["generated_css"])

    def test_light_gtk_mode_emits_light_preference(self) -> None:
        theme = copy.deepcopy(self.theme)
        theme["variant"] = "light"
        files, _ = render_theme(theme)
        self.assertIn("gtk-application-prefer-dark-theme=0", files["gtk/gtk-3.0/settings.ini"])

    def test_gtk_override_does_not_feed_back_into_other_targets(self) -> None:
        theme = copy.deepcopy(self.theme)
        theme["overrides"] = {"gtk": {"background": "#010203", "accent": "#abcdef"}}
        files, _ = render_theme(theme)
        self.assertIn("@define-color blox_bg #010203;", files["gtk/gtk-3.0/gtk.css"])
        self.assertIn("@define-color blox_accent #abcdef;", files["gtk/gtk-4.0/gtk.css"])
        self.assertEqual(self.theme["colours"], json.loads(files["quickshell/theme.json"])["colours"])

    def test_generated_gtk_css_parses_in_both_toolkits(self) -> None:
        files, _ = render_theme(self.theme)
        with tempfile.TemporaryDirectory() as temporary:
            for toolkit, name in (("gtk3", "gtk/gtk-3.0/gtk.css"), ("gtk4", "gtk/gtk-4.0/gtk.css")):
                with self.subTest(toolkit=toolkit):
                    path = Path(temporary) / f"{toolkit}.css"
                    path.write_text(files[name], encoding="utf-8")
                    completed = subprocess.run([sys.executable, str(THEMES / "tests/helpers/gtk_probe.py"), toolkit, "--css", str(path)], cwd=REPOSITORY, capture_output=True, text=True, check=False)
                    self.assertEqual(0, completed.returncode, completed.stderr)
                    self.assertEqual([], json.loads(completed.stdout)["errors"])

    def test_disabled_targets_are_not_rendered(self) -> None:
        theme = copy.deepcopy(self.theme)
        for target in theme["targets"]:
            theme["targets"][target] = False
        files, warnings = render_theme(theme)
        self.assertEqual({}, files)
        self.assertEqual([], warnings)

    def test_in_memory_commands_do_not_create_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_STATE_HOME"] = temporary
            for command in ("render", "preview", "diff", "doctor"):
                completed = run_cli(command, *([] if command == "doctor" else ["blox-panel"]), "--json", environment=environment)
                self.assertEqual(0, completed.returncode, completed.stderr or completed.stdout)
            self.assertEqual([], list(Path(temporary).iterdir()))

    def test_explicit_output_contains_only_rendered_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "render"
            completed = run_cli("render", "blox-panel", "--output", str(output), "--json")
            self.assertEqual(0, completed.returncode, completed.stderr or completed.stdout)
            files = sorted(str(path.relative_to(output)) for path in output.rglob("*") if path.is_file())
            expected = sorted([*render_theme(self.theme)[0], "manifest.json"])
            self.assertEqual(expected, files)


class CliContractTests(unittest.TestCase):
    def test_all_commands_support_human_and_json_output(self) -> None:
        commands = (("list",), ("show", "blox-panel"), ("validate", "blox-panel"), ("render", "blox-panel"), ("preview", "blox-panel"), ("diff", "blox-panel"), ("doctor",))
        for arguments in commands:
            with self.subTest(command=arguments[0], output="human"):
                completed = run_cli(*arguments)
                self.assertEqual(0, completed.returncode, completed.stderr)
                self.assertTrue(completed.stdout)
            with self.subTest(command=arguments[0], output="json"):
                completed = run_cli(*arguments, "--json")
                self.assertEqual(0, completed.returncode, completed.stderr)
                response = json.loads(completed.stdout)
                self.assertEqual({"api_version", "command", "ok", "status", "data", "warnings", "errors"}, set(response))
                self.assertEqual(arguments[0], response["command"])

    def test_missing_theme_and_malformed_json_exit_codes(self) -> None:
        missing = run_cli("show", "definitely-missing", "--json")
        self.assertEqual(4, missing.returncode)
        self.assertFalse(json.loads(missing.stdout)["ok"])
        with tempfile.TemporaryDirectory() as temporary:
            malformed_path = Path(temporary) / "malformed.json"
            malformed_path.write_text("{", encoding="utf-8")
            malformed = run_cli("show", str(malformed_path), "--json")
            self.assertEqual(3, malformed.returncode)
            self.assertFalse(json.loads(malformed.stdout)["ok"])

    def test_preview_reports_gtk_restart_and_libadwaita_boundaries(self) -> None:
        completed = run_cli("preview", "blox-panel", "--json")
        self.assertEqual(0, completed.returncode)
        response = json.loads(completed.stdout)
        self.assertTrue(response["data"]["gtk"]["restart_required"])
        self.assertEqual("partial-user-css", response["data"]["gtk"]["libadwaita_support"])
        self.assertTrue(any("Libadwaita" in warning for warning in response["warnings"]))
        self.assertEqual([20, 24], response["data"]["cursor"]["sizes"])
        self.assertIn("wait", response["data"]["cursor"]["states"])
        self.assertTrue(response["data"]["cursor"]["restart_required_for_existing_processes"])

    def test_repository_does_not_force_gtk_theme_environment(self) -> None:
        sources = (
            REPOSITORY / "environment/.config/environment.d/10-hyprland-appearance.conf",
            REPOSITORY / "hyprland/.config/hypr/conf.d/environment.lua",
        )
        for source in sources:
            self.assertNotIn("GTK_THEME", source.read_text(encoding="utf-8"), source)
        self.assertFalse((REPOSITORY / "systemd/user/xdg-desktop-portal-gtk.service.d/dark-theme.conf").exists())

    def test_usage_errors_exit_with_two(self) -> None:
        self.assertEqual(2, run_cli().returncode)
        self.assertEqual(2, run_cli("unknown-command").returncode)
        self.assertEqual(2, run_cli("show").returncode)

    def test_render_refuses_non_empty_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "render"
            output.mkdir()
            (output / "owned.txt").write_text("keep", encoding="utf-8")
            completed = run_cli("render", "blox-panel", "--output", str(output), "--json")
            self.assertEqual(5, completed.returncode)
            self.assertEqual("keep", (output / "owned.txt").read_text(encoding="utf-8"))
            self.assertEqual(["owned.txt"], [path.name for path in output.iterdir()])

    def test_render_refuses_live_state_and_symlink_to_it(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_STATE_HOME"] = temporary
            state = Path(temporary) / "blox-theme"
            state.mkdir()
            link = Path(temporary) / "state-link"
            link.symlink_to(state, target_is_directory=True)
            for output in (state, state / "candidate", link / "candidate"):
                with self.subTest(output=output):
                    completed = run_cli("render", "blox-panel", "--output", str(output), "--json", environment=environment)
                    self.assertEqual(5, completed.returncode)
            self.assertEqual([], list(state.iterdir()))

    def test_diff_reports_add_modify_and_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            environment = os.environ.copy()
            environment["XDG_STATE_HOME"] = temporary
            current = Path(temporary) / "blox-theme/current"
            files, _ = render_theme(load_theme("blox-panel")[1])
            for name, content in files.items():
                path = current / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            (current / "kitty/theme.conf").write_text("changed\n", encoding="utf-8")
            (current / "vicinae/theme.toml").unlink()
            completed = run_cli("diff", "blox-panel", "--json", environment=environment)
            self.assertEqual(0, completed.returncode)
            changes = {item["path"]: item["change"] for item in json.loads(completed.stdout)["data"]["changes"]}
            self.assertEqual("modify", changes["kitty/theme.conf"])
            self.assertEqual("add", changes["vicinae/theme.toml"])
            self.assertEqual("unchanged", changes["quickshell/theme.json"])


if __name__ == "__main__":
    unittest.main()
