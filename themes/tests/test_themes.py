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

from blox_theme.core import DEFAULT_BAR_ITEMS, dependency_checks, derive_ansi, list_themes, load_theme, render_manifest, render_theme, resolved_bar_items, schema_errors, validate_theme


def run_cli(*arguments: str, environment: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(THEMES / "bin/themectl"), *arguments], cwd=REPOSITORY, env=environment, capture_output=True, text=True, check=False)


class ThemeSchemaTests(unittest.TestCase):
    def test_canonical_theme_is_valid(self) -> None:
        _, theme = load_theme("blox-panel")
        result = validate_theme(theme)
        self.assertEqual([], result.errors)

    def test_bundled_wallpapers_are_home_relative_and_match_generator_digest(self) -> None:
        for theme_id in ("grass", "moonlight", "side-pywal", "daylight", "top-down-close", "top-down-wide"):
            with self.subTest(theme=theme_id):
                _, theme = load_theme(theme_id)
                source = theme["wallpaper"]["path"]
                wallpaper = Path(source).expanduser()
                self.assertTrue(source.startswith("~/Pictures/wallpapers/"))
                self.assertTrue(wallpaper.is_file())
                self.assertEqual(theme["generator"]["wallpaper_sha256"], hashlib.sha256(wallpaper.read_bytes()).hexdigest())

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

    def test_contrast_failure_is_a_warning(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["colours"]["foreground"] = theme["colours"]["background"]
        result = validate_theme(theme, check_dependencies=False)
        self.assertEqual([], result.errors)
        self.assertTrue(any("contrast" in warning for warning in result.warnings))

    def test_gtk_override_source_requires_values(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["gtk"]["colour_source"] = "override"
        result = validate_theme(theme, check_dependencies=False)
        self.assertTrue(any("overrides.gtk" in error for error in result.errors))
        theme["overrides"] = {"gtk": {"accent": "#abcdef"}}
        self.assertFalse(any("overrides.gtk" in error for error in validate_theme(theme, check_dependencies=False).errors))

    def test_low_contrast_gtk_override_is_a_warning(self) -> None:
        _, theme = load_theme("blox-panel")
        theme["overrides"] = {"gtk": {"foreground": theme["colours"]["background"]}}
        result = validate_theme(theme, check_dependencies=False)
        self.assertEqual([], result.errors)
        self.assertTrue(any("GTK override" in warning for warning in result.warnings))

    def test_schema_boundaries_and_unknown_nested_fields(self) -> None:
        _, source = load_theme("blox-panel")
        mutations = {
            "future schema": lambda theme: theme.update(schema_version=2),
            "invalid id": lambda theme: theme.update(id="Invalid ID"),
            "unknown target": lambda theme: theme["targets"].update(unknown=True),
            "unknown widget profile": lambda theme: theme.update(widgets={"profile": "arbitrary"}),
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

    def test_widget_schema_rejects_invalid_identifiers_and_unknown_fields(self) -> None:
        _, source = load_theme("blox-panel")
        widget = {
            "id": "clock",
            "name": "Clock",
            "type": "clock",
            "enabled": True,
            "content_command": "tty-clock -c",
            "left_click_command": "",
            "right_click_command": "",
            "interval_ms": 1000,
            "visibility": "always",
            "anchor": "top-left",
            "offset_x": 20,
            "offset_y": 20,
            "width": 0,
            "height": 0,
            "shape": "auto",
            "options": {},
        }
        mutations = {
            "invalid id": lambda value: value.update(id="Invalid Widget ID"),
            "unknown field": lambda value: value.update(unknown=True),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                theme = copy.deepcopy(source)
                candidate = copy.deepcopy(widget)
                mutate(candidate)
                theme["widgets"]["items"] = [candidate]
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
        self.assertIn("inactive_tab_background #000000", files["kitty/theme.conf"])
        self.assertIn("tab_bar_background none", files["kitty/theme.conf"])
        phase7 = {
            "hyprland/theme.lua", "hyprland/hyprtoolkit.conf", "hyprlock/theme.conf", "btop/theme.theme",
            "micro/blox-theme.micro", "glow/style.json",
            "cursor-editor/settings.json", "stylus/blox-system.user.css",
            "powerlevel10k/theme.zsh",
            "widgets/profile.json",
        }
        self.assertTrue(phase7.issubset(files))
        self.assertNotIn("code/settings.json", files)

    def test_code_target_renders_complete_extension(self) -> None:
        self.theme["targets"]["code"] = True
        files, _ = render_theme(self.theme)
        code_settings = json.loads(files["code/settings.json"])
        self.assertEqual(self.theme["fonts"]["mono"], code_settings["editor.fontFamily"])
        self.assertEqual("Blox Dark 2026", code_settings["workbench.colorTheme"])
        self.assertNotIn("workbench.colorCustomizations", code_settings)
        package = json.loads(files["code/package.json"])
        self.assertEqual("./themes/blox-dark-2026.json", package["contributes"]["themes"][0]["path"])
        code_theme = json.loads(files["code/themes/blox-dark-2026.json"])
        self.assertIn("sideBarSectionHeader.background", code_theme["colors"])
        self.assertTrue(code_theme["semanticHighlighting"])
        obsidian = json.loads(files["obsidian/style-settings.json"])
        self.assertEqual(self.theme["colours"]["background"], obsidian["minimal-style@@bg1@@dark"])
        self.assertEqual(self.theme["colours"]["accent"], obsidian["minimal-style@@ax1@@dark"])
        shell = json.loads(files["quickshell/theme.json"])["shell"]
        expected_shell = self.theme.get("shell", {})
        self.assertEqual(expected_shell.get("bar", {}).get("position", "left"), shell["bar"]["position"])
        expected_bar_items = resolved_bar_items(expected_shell.get("bar"))
        self.assertEqual(
            {item["id"]: item for item in expected_bar_items},
            {item["id"]: item for item in shell["bar"]["items"]},
        )
        self.assertEqual(expected_shell.get("osd", {}).get("position", "top-left"), shell["osd"]["position"])
        self.assertEqual(expected_shell.get("notifications", {}).get("position", "bottom-right"), shell["notifications"]["position"])
        self.assertIn("workbench.colorCustomizations", json.loads(files["cursor-editor/settings.json"]))
        self.assertIn("@-moz-document", files["stylus/blox-system.user.css"])
        self.assertIn('color-link default "#cdd6f4"', files["micro/blox-theme.micro"])
        self.assertNotIn('color-link default "#cdd6f4,#242424"', files["micro/blox-theme.micro"])
        hyprtoolkit = files["hyprland/hyprtoolkit.conf"]
        self.assertIn("background = 0xFF242424", hyprtoolkit)
        self.assertIn("accent = 0xFF89B4FA", hyprtoolkit)
        self.assertIn("icon_theme = Adwaita", hyprtoolkit)
        self.assertIn("font_family = Google Sans", hyprtoolkit)

    def test_bar_item_overrides_are_rendered_with_complete_registry(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "bottom", "items": [
                {"id": "clock", "enabled": False, "region": "end", "order": 7},
                {"id": "wifi", "enabled": True, "region": "start", "order": 0},
            ]},
            "osd": {"position": "centre-bottom", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "top-right", "offset_x": 0, "offset_y": 0},
        }
        self.assertEqual([], schema_errors(self.theme))
        shell = json.loads(render_theme(self.theme)[0]["quickshell/theme.json"])["shell"]
        items = {item["id"]: item for item in shell["bar"]["items"]}
        self.assertEqual(len(DEFAULT_BAR_ITEMS), len(items))
        self.assertEqual({"id": "clock", "enabled": False, "region": "end", "order": 7}, items["clock"])
        self.assertEqual("start", items["wifi"]["region"])
        self.assertTrue(items["power"]["enabled"])
        self.assertEqual("toggle", items["battery"]["display"])
        self.assertEqual("hidden", items["touchpad"]["region"])
        for item_id in ("touchpad", "fan", "gpu"):
            self.assertEqual("normal", items[item_id]["visibility"])

    def test_bar_item_schema_rejects_unknown_items_and_regions(self) -> None:
        base_shell = {
            "bar": {"position": "left", "items": []},
            "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
        }
        for item in (
            {"id": "unknown", "enabled": True, "region": "start", "order": 0},
            {"id": "power", "enabled": True, "region": "middle", "order": 0},
        ):
            candidate = copy.deepcopy(self.theme)
            candidate["shell"] = copy.deepcopy(base_shell)
            candidate["shell"]["bar"]["items"] = [item]
            self.assertTrue(schema_errors(candidate))

    def test_battery_display_mode_is_validated_and_rendered(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "left", "items": [
                {"id": "battery", "enabled": True, "region": "end", "order": 0, "display": "numeric"},
            ]},
            "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
        }
        self.assertEqual([], schema_errors(self.theme))
        shell = json.loads(render_theme(self.theme)[0]["quickshell/theme.json"])["shell"]
        items = {item["id"]: item for item in shell["bar"]["items"]}
        self.assertEqual("numeric", items["battery"]["display"])

        self.theme["shell"]["bar"]["items"][0]["display"] = "both"
        self.assertTrue(schema_errors(self.theme))

    def test_runtime_item_visibility_is_validated_and_rendered(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "left", "items": [
                {"id": "touchpad", "enabled": True, "region": "end", "order": 0, "visibility": "always"},
            ]},
            "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
        }
        self.assertEqual([], schema_errors(self.theme))
        shell = json.loads(render_theme(self.theme)[0]["quickshell/theme.json"])["shell"]
        items = {item["id"]: item for item in shell["bar"]["items"]}
        self.assertEqual("always", items["touchpad"]["visibility"])

        self.theme["shell"]["bar"]["items"][0]["visibility"] = "sometimes"
        self.assertTrue(schema_errors(self.theme))

    def test_legacy_tray_override_migrates_to_application_tray(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "left", "items": [
                {"id": "tray", "enabled": False, "region": "hidden", "order": 9},
            ]},
            "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
        }
        shell = json.loads(render_theme(self.theme)[0]["quickshell/theme.json"])["shell"]
        items = {item["id"]: item for item in shell["bar"]["items"]}
        self.assertTrue(items["tray"]["enabled"])
        self.assertEqual("end", items["tray"]["region"])
        self.assertFalse(items["application-tray"]["enabled"])
        self.assertEqual(
            min(item["order"] for item in items.values() if item["region"] == "hidden"),
            items["application-tray"]["order"],
        )

    def test_application_tray_is_pinned_furthest_from_the_tray_arrow(self) -> None:
        for tray_region, tray_order, expected_boundary in (
            ("start", 99, "last"),
            ("end", 0, "first"),
            ("centre", -1, "first"),
            ("centre", 99, "last"),
        ):
            with self.subTest(tray_region=tray_region, tray_order=tray_order):
                items = resolved_bar_items({
                    "position": "top",
                    "items": [
                        {"id": "tray", "enabled": True, "region": tray_region, "order": tray_order},
                        {"id": "application-tray", "enabled": True, "region": "start", "order": 2},
                    ],
                })
                application_tray = next(item for item in items if item["id"] == "application-tray")
                hidden_ids = [
                    item["id"]
                    for item in sorted(
                        (item for item in items if item["region"] == "hidden"),
                        key=lambda item: item["order"],
                    )
                ]
                self.assertEqual("hidden", application_tray["region"])
                self.assertEqual(
                    "application-tray",
                    hidden_ids[0] if expected_boundary == "first" else hidden_ids[-1],
                )

    def test_shell_offsets_are_not_artificially_limited(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "left", "items": []},
            "osd": {"position": "top-left", "offset_x": 12000, "offset_y": -12000},
            "notifications": {"position": "bottom-right", "offset_x": -12000, "offset_y": 12000},
        }
        self.assertEqual([], schema_errors(self.theme))

    def test_bar_item_validation_rejects_duplicate_ids(self) -> None:
        self.theme["shell"] = {
            "bar": {"position": "left", "items": [
                {"id": "power", "enabled": True, "region": "start", "order": 0},
                {"id": "power", "enabled": False, "region": "end", "order": 1},
            ]},
            "osd": {"position": "top-left", "offset_x": 0, "offset_y": 0},
            "notifications": {"position": "bottom-right", "offset_x": 0, "offset_y": 0},
        }
        result = validate_theme(self.theme, check_dependencies=False)
        self.assertTrue(any("duplicate item ids" in error for error in result.errors))

    def test_phase7_targets_are_isolated(self) -> None:
        target_files = {
            "hyprland": ["hyprland/hyprtoolkit.conf", "hyprland/theme.lua"],
            "hyprlock": "hyprlock/theme.conf",
            "btop": "btop/theme.theme", "micro": "micro/blox-theme.micro",
            "glow": "glow/style.json", "code": ["code/package.json", "code/settings.json", "code/themes/blox-dark-2026.json"],
            "cursor_editor": "cursor-editor/settings.json", "stylus": "stylus/blox-system.user.css",
            "powerlevel10k": "powerlevel10k/theme.zsh",
            "widgets": "widgets/profile.json",
        }
        for target, expected in target_files.items():
            with self.subTest(target=target):
                theme = copy.deepcopy(self.theme)
                for key in theme["targets"]:
                    theme["targets"][key] = key == target
                files, _ = render_theme(theme)
                self.assertEqual(expected if isinstance(expected, list) else [expected], list(files))

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
        gtk4 = files["gtk/gtk-4.0/gtk.css"]
        self.assertTrue(metadata["generated_css"])
        self.assertEqual("partial-user-css", metadata["libadwaita_support"])
        self.assertIn("gtk-theme-name=Graphite-Dark-compact", files["gtk/gtk-3.0/settings.ini"])
        self.assertIn("gtk-font-name=Google Sans 11", files["gtk/gtk-4.0/settings.ini"])
        self.assertIn("@define-color blox_accent #89b4fa;", files["gtk/gtk-3.0/gtk.css"])
        self.assertIn("switch:checked", gtk4)
        self.assertIn("\nwindow {\n", gtk4)
        self.assertNotIn("\n.background {\n", gtk4)

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
    def test_detached_widgets_export_import_round_trip_and_validation(self) -> None:
        widgets = {
            "profile": "compact",
            "items": [{
                "id": "clock",
                "name": "Clock",
                "type": "clock",
                "enabled": True,
                "content_command": "tty-clock -c",
                "left_click_command": "",
                "right_click_command": "",
                "interval_ms": 1000,
                "visibility": "always",
                "anchor": "top-right",
                "offset_x": 24,
                "offset_y": 32,
                "width": 320,
                "height": 180,
                "shape": "rounded",
                "options": {"seconds": True},
            }],
        }
        with tempfile.TemporaryDirectory() as temporary:
            exported = Path(temporary) / "widgets.json"
            result = run_cli("widgets-export", json.dumps(widgets), "--output", str(exported), "--json")
            self.assertEqual(0, result.returncode, result.stderr)
            document = json.loads(exported.read_text(encoding="utf-8"))
            self.assertEqual({"schema_version": 1, "kind": "blox-widgets", "widgets": widgets}, document)

            imported = run_cli("widgets-import", str(exported), "--json")
            self.assertEqual(0, imported.returncode, imported.stderr)
            self.assertEqual(widgets, json.loads(imported.stdout)["data"])

            malformed = Path(temporary) / "not-widgets.json"
            malformed.write_text(json.dumps({"schema_version": 1, "widgets": widgets}), encoding="utf-8")
            rejected_document = run_cli("widgets-import", str(malformed), "--json")
            self.assertEqual(3, rejected_document.returncode)
            self.assertFalse(json.loads(rejected_document.stdout)["ok"])

            invalid_widgets = copy.deepcopy(widgets)
            invalid_widgets["items"][0]["id"] = "Invalid Widget ID"
            rejected_widget = run_cli("widgets-export", json.dumps(invalid_widgets), "--output", str(Path(temporary) / "invalid.json"), "--json")
            self.assertEqual(3, rejected_widget.returncode)
            self.assertFalse(json.loads(rejected_widget.stdout)["ok"])

    def test_theme_picker_exposes_widget_tab_editor_and_detached_io(self) -> None:
        modules = REPOSITORY / "quickshell/.config/quickshell/blox/modules"
        widgets = (modules / "ThemePickerWidgets.qml").read_text(encoding="utf-8")
        modal = (modules / "ThemePickerModal.qml").read_text(encoding="utf-8")
        dialogs = (modules / "ThemePickerFileDialogs.qml").read_text(encoding="utf-8")
        for source, expected in (
            (widgets, 'text: "Widgets"'),
            (widgets, 'text: "New Widget"'),
            (widgets, 'Import"'),
            (widgets, 'Export"'),
            (modal, 'text: "Save widget"'),
            (dialogs, 'id: widgetImportDialog'),
            (dialogs, 'id: widgetExportDialog'),
            (dialogs, 'controller.runApi("widgets-import"'),
            (dialogs, 'controller.runApi("widgets-export"'),
            (widgets, 'controller.openWidgetEditor(-1)'),
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, source)

    def test_bar_consumes_configured_regions_and_positions(self) -> None:
        source = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml").read_text(encoding="utf-8")
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        status_item = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarStatusItem.qml").read_text(encoding="utf-8")
        clock_item = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarClockItem.qml").read_text(encoding="utf-8")
        region = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarRegion.qml").read_text(encoding="utf-8")
        for expected in (
            'regionItems: Theme.barStartItems',
            'regionItems: Theme.barCentreItems',
            'regionItems: Theme.barEndItems',
            'Theme.barPosition === "left"',
            'Theme.barPosition === "right"',
            'Theme.barPosition === "top"',
            'Theme.barPosition === "bottom"',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, source)
        self.assertIn('model: Theme.barHiddenItems.filter', source)
        for item_id in ("power", "notes", "workspaces", "clock", "battery", "notifications", "wifi", "sound", "privacy", "awake", "display", "bt", "updates", "fan", "gpu", "touchpad", "tray", "application-tray"):
            with self.subTest(item_id=item_id):
                self.assertIn(f'"{item_id}"', delegate)
        edge_trigger = source.split("MouseArea {", 1)[1].split("Rectangle {", 1)[0]
        self.assertIn("readonly property int triggerLength", edge_trigger)
        self.assertIn("width: root.horizontalBar ? triggerLength : 1", edge_trigger)
        self.assertIn("height: root.horizontalBar ? 1 : triggerLength", edge_trigger)
        self.assertIn("parent.width - width", edge_trigger)
        self.assertIn(": parent.height - height", edge_trigger)
        self.assertIn("root.enterEdgeTrigger()", edge_trigger)
        self.assertIn("root.leaveEdgeTrigger()", edge_trigger)
        self.assertIn('Theme.barPosition === "bottom"', edge_trigger)
        self.assertIn('Theme.barPosition === "right"', edge_trigger)
        self.assertIn("Hyprland.activeToplevel.lastIpcObject", source)
        self.assertIn("Hyprland.refreshToplevels()", source)
        self.assertIn("ToplevelManager.activeToplevel", source)
        self.assertIn("activeWaylandToplevel.fullscreen", source)
        self.assertIn("readonly property bool fullscreenActive", source)
        self.assertIn("readonly property bool barPinnedOpen: barOpen && !fullscreenActive", source)
        self.assertIn("exclusiveZone: root.barPinnedOpen", source)
        self.assertEqual(6, source.count("BarRegion {"))
        self.assertIn("BarItemDelegate {", region)
        self.assertIn("Row {", region)
        self.assertIn("Column {", region)
        self.assertIn("root.regionItems.length - 1", region)
        self.assertIn("root.trayHost.registerTrayToggle(this, root.horizontal)", region)
        self.assertIn("root.trayHost.unregisterTrayToggle(this, root.horizontal)", region)
        self.assertIn("function publishNotificationPosition()", delegate)
        self.assertIn("anchors.fill: parent", delegate)
        self.assertIn("horizontal !== surfaceController.horizontalBar", delegate)
        self.assertIn("notificationController.panelY = mappedCentre", delegate)
        self.assertIn("onHorizontalChanged: publishNotificationPosition()", delegate)
        self.assertIn("function onHorizontalBarChanged()", delegate)
        self.assertIn('return content.network.json.icon || "󰤩"', status_item)
        self.assertNotIn('return content.network.json.icon || "󰔩"', status_item)
        self.assertIn("text: root.context.contentController.railClockText(root.context.horizontal)", clock_item)
        self.assertNotIn("text: root.context.contentController.railClockText()", clock_item)

    def test_bar_uses_explicit_domain_controllers(self) -> None:
        bar = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml").read_text(encoding="utf-8")
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        content = (REPOSITORY / "quickshell/.config/quickshell/blox/services/BarContentController.qml").read_text(encoding="utf-8")

        for controller in (
            "BarContentController {",
            "WorkspaceController {",
            "NotificationController {",
        ):
            with self.subTest(controller=controller):
                self.assertIn(controller, bar)

        for controller_property in (
            "required property BarContentController contentController",
            "required property WorkspaceController workspaceController",
            "required property NotificationController notificationController",
        ):
            with self.subTest(controller_property=controller_property):
                self.assertIn(controller_property, delegate)

        self.assertIn("BarStatus {", content)
        self.assertIn("BarActions {", content)
        self.assertIn("BarContent {", content)
        for stale_forwarder in (
            "property alias battery:",
            "function workspaceItems()",
            "function notificationStatus()",
            "function run(command)",
            "function railClockText(horizontal)",
        ):
            with self.subTest(stale_forwarder=stale_forwarder):
                self.assertNotIn(stale_forwarder, bar)

    def test_bar_items_and_popouts_use_domain_components(self) -> None:
        shared = REPOSITORY / "quickshell/.config/quickshell/blox/shared"
        delegate = (shared / "BarItemDelegate.qml").read_text(encoding="utf-8")
        popouts = (REPOSITORY / "quickshell/.config/quickshell/blox/popouts/BarPopouts.qml").read_text(encoding="utf-8")

        for component in (
            "BarLauncherItem {",
            "BarWorkspaceItem {",
            "BarClockItem {",
            "BarBatteryItem {",
            "BarNotificationItem {",
            "BarStatusItem {",
            "BarTrayItem {",
        ):
            with self.subTest(item_component=component):
                self.assertIn(component, delegate)

        for wrapper in (
            "BarLauncherItem.qml",
            "BarStatusItem.qml",
            "BarTrayItem.qml",
        ):
            source = (shared / wrapper).read_text(encoding="utf-8")
            with self.subTest(sized_wrapper=wrapper):
                self.assertIn("loader.item.implicitWidth || loader.item.width", source)
                self.assertIn("loader.item.implicitHeight || loader.item.height", source)

        for component in (
            "BarNotesSurface {",
            "BarTrayMenuSurface {",
            "BarCalendarSurface {",
            "BarSystemSurfaces {",
            "BarNotificationSurface {",
            "BarBasicSurface {",
        ):
            with self.subTest(popout_component=component):
                self.assertIn(component, popouts)

        for controller_property in (
            "required property var surfaceController",
            "required property BarContentController contentController",
            "required property NotificationController notificationController",
            "required property UiState persistentState",
        ):
            with self.subTest(controller_property=controller_property):
                self.assertIn(controller_property, popouts)

        for stale_forwarder in (
            "property string openPanel:",
            "property var todoStatus",
            "property string systemTitle:",
            "property var notificationsModel:",
            "signal previousTodo()",
            "signal systemAction(",
            "signal basicAction(",
        ):
            with self.subTest(stale_forwarder=stale_forwarder):
                self.assertNotIn(stale_forwarder, popouts)

        self.assertNotIn("PanelRailButton {", delegate)
        self.assertNotIn("HoverPopupWindow {", popouts)

    def test_configured_battery_uses_live_status_without_cross_axis_jump(self) -> None:
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        battery = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarBatteryItem.qml").read_text(encoding="utf-8")
        clock = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarClockItem.qml").read_text(encoding="utf-8")
        self.assertEqual(2, battery.count("status: root.context.contentController.battery.json"))
        self.assertIn("implicitWidth: !contentVisible ? 0 : root.horizontal", delegate)
        self.assertIn("implicitHeight: !contentVisible ? 0 : !root.horizontal", delegate)
        self.assertNotIn("trayToggleItem = root", battery)
        self.assertIn("Math.ceil(horizontalClock.implicitWidth) + 16", clock)
        self.assertIn("id: horizontalClock", clock)
        self.assertIn("anchors.centerIn: parent", clock)
        bar = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml").read_text(encoding="utf-8")
        self.assertIn("property var verticalTrayToggleItem", bar)
        self.assertIn("property var horizontalTrayToggleItem", bar)
        self.assertIn("readonly property point horizontalTrayPoint", bar)
        self.assertIn("while (ancestor && ancestor !== configuredRail)", bar)
        self.assertIn("ancestor = ancestor.parent", bar)

    def test_configured_battery_supports_display_modes(self) -> None:
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        battery = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarBatteryItem.qml").read_text(encoding="utf-8")
        self.assertIn('readonly property string batteryDisplay: itemConfig.display || "toggle"', delegate)
        self.assertIn('context.batteryDisplay !== "numeric"', battery)
        self.assertIn('context.batteryDisplay === "numeric"', battery)
        self.assertIn('root.context.batteryDisplay !== "toggle"', battery)
        self.assertIn('collapsible: root.context.batteryDisplay === "toggle"', battery)

    def test_configured_touchpad_toggles_and_refreshes_live_status(self) -> None:
        status_item = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarStatusItem.qml").read_text(encoding="utf-8")
        status = (REPOSITORY / "quickshell/.config/quickshell/blox/services/BarStatus.qml").read_text(encoding="utf-8")
        touchpad = status_item.split("id: touchpadComponent", 1)[1]
        self.assertIn("root.context.contentController.touchpad.json.icon", touchpad)
        self.assertIn('"/osd/control.sh touchpad-toggle"', touchpad)
        self.assertIn("onHovered: root.context.surfaceController.trayEntered()", touchpad)
        self.assertIn("onExited: root.context.surfaceController.trayExited()", touchpad)
        self.assertIn('"/quickshell-touchpad-enabled"', status)
        self.assertIn("watchChanges: true", status)
        self.assertIn("onFileChanged: touchpad.refresh()", status)

    def test_runtime_application_tray_order_uses_the_tray_opening_direction(self) -> None:
        document = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/ThemeDocumentController.qml").read_text(encoding="utf-8")
        defaults = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/ThemeDefaults.qml").read_text(encoding="utf-8")
        self.assertIn("defaults.resolvedBarItems(data.bar && data.bar.items ? data.bar.items : [])", document)
        resolver = defaults.split("function resolvedBarItems(overrides)", 1)[1].split("function barItemsForRegion", 1)[0]
        self.assertIn("if (trayOpensForward(items))", resolver)
        self.assertIn("hidden.unshift(applicationTray)", resolver)
        self.assertIn("hidden.push(applicationTray)", resolver)

    def test_horizontal_popouts_use_screen_geometry_and_do_not_overlap(self) -> None:
        notifications = (REPOSITORY / "quickshell/.config/quickshell/blox/popouts/BarNotificationSurface.qml").read_text(encoding="utf-8")
        geometry = (REPOSITORY / "quickshell/.config/quickshell/blox/popouts/BarPopoutGeometry.qml").read_text(encoding="utf-8")
        system = (REPOSITORY / "quickshell/.config/quickshell/blox/popouts/BarSystemSurfaces.qml").read_text(encoding="utf-8")
        self.assertIn("maxPopoutHeight: Math.min(720, Math.max(240, root.geometry.screenHeight - 16))", notifications)
        self.assertIn("function adjacentPopupX", geometry)
        self.assertIn("root.geometry.adjacentPopupX(mediaPlayer.implicitWidth, systemWindow.anchorX, systemPopout.width)", system)

        tray = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarTrayItem.qml").read_text(encoding="utf-8")
        application_tray = tray.split("id: applicationTrayComponent", 1)[1]
        self.assertIn("flow: root.context.horizontal ? Flow.LeftToRight : Flow.TopToBottom", application_tray)
        self.assertIn("trayCount * Theme.buttonSize", application_tray)
        self.assertIn("anchors.fill: parent", application_tray)
        self.assertIn("HoverHandler {", application_tray)
        self.assertIn("root.context.surfaceController.trayEntered()", application_tray)
        self.assertIn("root.context.surfaceController.trayExited()", application_tray)
        tray_item = application_tray.split("TrayRailItem {", 1)[1]
        self.assertNotIn("onExited:", tray_item)

    def test_notes_header_keeps_actions_together_and_swaps_only_on_the_right(self) -> None:
        notes = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/popouts/NotesPopout.qml"
        ).read_text(encoding="utf-8")
        notes_surface = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/popouts/BarNotesSurface.qml"
        ).read_text(encoding="utf-8")
        self.assertIn("property bool headerActionsOnRight: false", notes)
        self.assertIn('headerActionsOnRight: Theme.barPosition === "right"', notes_surface)
        self.assertIn("root.geometry.openPanelX > root.geometry.screenWidth / 2", notes_surface)
        self.assertIn(
            "layoutDirection: root.headerActionsOnRight ? Qt.RightToLeft : Qt.LeftToRight",
            notes,
        )
        self.assertIn("horizontalAlignment: root.headerActionsOnRight ? Text.AlignLeft : Text.AlignRight", notes)

    def test_media_popout_is_hidden_without_a_player(self) -> None:
        system = (REPOSITORY / "quickshell/.config/quickshell/blox/popouts/BarSystemSurfaces.qml").read_text(encoding="utf-8")
        self.assertIn('root.surfaceController.openPanel === "audio" && mediaPlayer.hasPlayers', system)

    def test_system_popout_splits_state_and_mode_sections(self) -> None:
        popouts = REPOSITORY / "quickshell/.config/quickshell/blox/popouts"
        system = (popouts / "SystemPopout.qml").read_text(encoding="utf-8")
        controller = (popouts / "SystemPopoutController.qml").read_text(encoding="utf-8")
        audio = (popouts / "SystemAudioSection.qml").read_text(encoding="utf-8")
        connectivity = (popouts / "SystemConnectivitySection.qml").read_text(encoding="utf-8")
        display = (popouts / "SystemDisplaySection.qml").read_text(encoding="utf-8")

        for component in (
            "SystemPopoutController {",
            "SystemAudioSection {",
            "SystemConnectivitySection {",
            "SystemDisplaySection {",
        ):
            with self.subTest(component=component):
                self.assertIn(component, system)

        self.assertNotIn("component LevelSlider:", system)
        self.assertNotIn("component SectionButton:", system)
        self.assertIn("function queueAudio(value)", controller)
        self.assertIn("function queueBrightness(value)", controller)
        self.assertIn("audio-set-silent", controller)
        self.assertIn("brightness-set-silent", controller)
        self.assertIn('"/control.sh mic " + id', audio)
        self.assertIn('"/control.sh wifi " + id', connectivity)
        self.assertIn('"/control.sh bluetooth " + id', connectivity)
        self.assertIn('"/display/blue-light-mode.sh " + id', display)

    def test_fan_and_gpu_are_configurable_runtime_items(self) -> None:
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        status_item = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarStatusItem.qml").read_text(encoding="utf-8")
        for item_id in ("fan", "gpu"):
            with self.subTest(item_id=item_id):
                self.assertIn(f'"{item_id}"', delegate)
        self.assertIn('profile === "Performance" ? "󱑬"', status_item)
        self.assertIn('content.systemInfo.json.profile === "Quiet"', status_item)
        self.assertIn('gpuMode === "gaming" ? "󰪫"', status_item)
        self.assertIn('content.systemInfo.json.gpuMode === "eco"', status_item)
        self.assertIn("visible: contentVisible", delegate)
        self.assertIn("readonly property bool runtimeSuppressed", delegate)
        self.assertIn("contentLoader.item !== null && !runtimeSuppressed", delegate)
        self.assertNotIn("contentLoader.item !== null && contentLoader.item.visible", delegate)

    def test_numeric_battery_hover_opens_the_system_popout(self) -> None:
        battery = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarBatteryItem.qml").read_text(encoding="utf-8")
        self.assertIn("BatteryCapacityTile {", battery)
        self.assertIn('hoverButtonEntered("system"', battery)
        self.assertIn('hoverButtonExited("battery")', battery)

    def test_runtime_item_visibility_can_bypass_normal_state_suppression(self) -> None:
        delegate = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarItemDelegate.qml").read_text(encoding="utf-8")
        self.assertIn('readonly property string itemVisibility: itemConfig.visibility || "normal"', delegate)
        self.assertIn('itemVisibility === "always" ? false', delegate)
        self.assertIn('itemId === "touchpad" ? contentController.touchpad.json.enabled !== false', delegate)
        self.assertIn('profile === undefined || contentController.systemInfo.json.profile === "Quiet"', delegate)
        self.assertIn('gpuMode === undefined || contentController.systemInfo.json.gpuMode === "eco"', delegate)
        status_item = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarStatusItem.qml").read_text(encoding="utf-8")
        self.assertNotIn("visible:", status_item)

    def test_application_tray_uses_the_repeater_count(self) -> None:
        tray = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/BarTrayItem.qml").read_text(encoding="utf-8")
        application_tray = tray.split("id: applicationTrayComponent", 1)[1]
        self.assertIn("id: trayRepeater", application_tray)
        self.assertIn("readonly property int trayCount: trayRepeater.count", application_tray)
        self.assertIn("width: implicitWidth", application_tray)
        self.assertIn("height: implicitHeight", application_tray)
        self.assertNotIn("SystemTray.items.length", application_tray)
        bar = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml").read_text(encoding="utf-8")
        hidden_drawers = bar.split("model: Theme.barHiddenItems", 1)[0].rsplit("Column {", 1)[1]
        self.assertIn("z: 100", hidden_drawers)

    def test_theme_list_exposes_visual_preview_data(self) -> None:
        entries = list_themes()
        self.assertTrue(entries)
        preview = entries[0]["preview"]
        self.assertIn("colours", preview)
        self.assertIn("wallpaper", preview)
        self.assertEqual({"ui", "mono", "panel"}, set(preview["fonts"]))
        self.assertIn(preview["bar"]["position"], {"left", "right", "top", "bottom"})
        self.assertTrue(preview["bar"]["items"])

    def test_tray_toggle_points_towards_its_placement_dependent_drawer(self) -> None:
        toggle = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/TrayToggleButton.qml").read_text(encoding="utf-8")
        self.assertIn('icon: horizontal ? "󰅂" : "󰅀"', toggle)
        self.assertIn("property bool opensForward: false", toggle)
        self.assertIn("iconRotation: active === opensForward ? 180 : 0", toggle)

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

    def test_osd_position_uses_window_edge_flags(self) -> None:
        source = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Osd.qml").read_text(encoding="utf-8")
        self.assertIn("id: osdWindow", source)
        for edge in ("onLeft", "onRight", "onTop", "onBottom"):
            self.assertIn(f"readonly property bool {edge}", source)
            self.assertNotIn(f"parent.{edge}", source)
        for edge in ("left", "right", "top", "bottom"):
            self.assertIn(f"{edge}: on{edge.title()}", source)

    def test_osd_animation_translates_from_its_configured_screen_edge(self) -> None:
        source = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/Osd.qml").read_text(encoding="utf-8")
        self.assertIn("transform: Translate", source)
        self.assertIn("osdWindow.onTop ? -osdCard.height - osdWindow.restingGap : osdWindow.height", source)
        self.assertNotIn("y: root.showing ? (osdWindow.onTop", source)

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
        self.assertEqual([22, 24], response["data"]["cursor"]["sizes"])
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
