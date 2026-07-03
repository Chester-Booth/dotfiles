from __future__ import annotations

import copy
import hashlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


THEMES = Path(__file__).resolve().parents[1]
REPOSITORY = THEMES.parent
sys.path.insert(0, str(THEMES / "lib"))

from blox_theme import cli
from blox_theme.core import load_theme


class ThemeLibraryMutationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.library = self.root / "themes"
        (self.library / "themes").mkdir(parents=True)
        self.source = load_theme("blox-panel")[1]
        (self.library / "themes/blox-panel.json").write_text(json.dumps(self.source), encoding="utf-8")
        self.patch = mock.patch("blox_theme.cli.themes_dir", return_value=self.library)
        self.patch.start()

    def tearDown(self) -> None:
        self.patch.stop()
        self.temporary.cleanup()

    def invoke(self, *arguments: str) -> tuple[dict, int]:
        return cli.run(cli.parser().parse_args(arguments))

    def test_duplicate_rename_and_confirmed_delete_preserve_stable_ids(self) -> None:
        duplicate, code = self.invoke("duplicate", "blox-panel", "phase6-copy", "--name", "Phase Six Copy", "--json")
        self.assertEqual(0, code)
        self.assertEqual("phase6-copy", duplicate["data"]["id"])
        copied = json.loads((self.library / "themes/phase6-copy.json").read_text(encoding="utf-8"))
        self.assertEqual("phase6-copy", copied["id"])

        renamed, code = self.invoke("rename", "phase6-copy", "Renamed Display", "--json")
        self.assertEqual(0, code)
        self.assertEqual("phase6-copy", renamed["data"]["id"])
        self.assertEqual("Renamed Display", json.loads((self.library / "themes/phase6-copy.json").read_text())["name"])

        refused, code = self.invoke("delete", "phase6-copy", "--json")
        self.assertEqual(2, code)
        self.assertTrue((self.library / "themes/phase6-copy.json").exists())
        with mock.patch("blox_theme.cli.current_generation", return_value=None):
            deleted, code = self.invoke("delete", "phase6-copy", "--yes", "--json")
        self.assertEqual(0, code)
        self.assertTrue(deleted["data"]["deleted"])
        self.assertFalse((self.library / "themes/phase6-copy.json").exists())
        self.assertFalse(list((self.library / "themes").glob(".*.tmp")))

    def test_delete_protects_canonical_active_and_unsafe_references(self) -> None:
        _, code = self.invoke("delete", "blox-panel", "--yes", "--json")
        self.assertEqual(3, code)
        _, code = self.invoke("delete", "../escape", "--yes", "--json")
        self.assertEqual(2, code)
        self.invoke("duplicate", "blox-panel", "active-copy", "--json")
        active = (Path("generation"), {"theme_id": "active-copy"})
        with mock.patch("blox_theme.cli.current_generation", return_value=active):
            response, code = self.invoke("delete", "active-copy", "--yes", "--json")
        self.assertEqual(3, code)
        self.assertIn("active", response["errors"][0])

    def test_replace_requires_matching_digest_and_never_changes_id(self) -> None:
        path = self.library / "themes/blox-panel.json"
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        candidate = copy.deepcopy(self.source)
        candidate["name"] = "Updated Display"
        response, code = self.invoke("save", json.dumps(candidate), "--replace", "--expect-sha256", digest, "--json")
        self.assertEqual(0, code)
        self.assertEqual("blox-panel", json.loads(path.read_text())["id"])
        self.assertEqual("Updated Display", json.loads(path.read_text())["name"])

        stale = copy.deepcopy(candidate)
        stale["name"] = "Should Not Win"
        response, code = self.invoke("save", json.dumps(stale), "--replace", "--expect-sha256", digest, "--json")
        self.assertEqual(6, code)
        self.assertIn("changed since", response["errors"][0])
        self.assertEqual("Updated Display", json.loads(path.read_text())["name"])

    def test_duplicate_refuses_invalid_or_existing_id(self) -> None:
        response, code = self.invoke("duplicate", "blox-panel", "Invalid ID", "--json")
        self.assertEqual(3, code)
        self.assertTrue(response["errors"])
        response, code = self.invoke("duplicate", "blox-panel", "blox-panel", "--json")
        self.assertEqual(6, code)
        self.assertIn("already exists", response["errors"][0])

    def test_inline_preview_is_side_effect_free_and_inline_apply_is_rejected(self) -> None:
        candidate = copy.deepcopy(self.source)
        for target in candidate["targets"]:
            candidate["targets"][target] = target == "quickshell"
        inline = json.dumps(candidate)

        with mock.patch("blox_theme.cli.apply_theme") as apply_theme:
            response, code = self.invoke("preview", inline, "--json")
            self.assertEqual(0, code, response)
            self.assertTrue(response["ok"])
            apply_theme.assert_not_called()

            response, code = self.invoke("apply", inline, "--json")
            self.assertEqual(3, code)
            self.assertIn("saved source theme", response["errors"][0])
            apply_theme.assert_not_called()

    def test_mutations_reject_a_non_object_source(self) -> None:
        path = self.library / "themes/broken.json"
        path.write_text("[]", encoding="utf-8")
        response, code = self.invoke("rename", "broken", "Still Broken", "--json")
        self.assertEqual(3, code)
        self.assertIn("JSON object", response["errors"][0])
        self.assertEqual([], json.loads(path.read_text(encoding="utf-8")))


class PickerIntegrationSourceTests(unittest.TestCase):
    def test_picker_uses_json_api_and_has_confirmation_paths(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        rules = (REPOSITORY / "hyprland/.config/hypr/conf.d/rules.lua").read_text(encoding="utf-8")
        for action in ("list", "show", "preview", "generate", "save", "apply", "duplicate", "rename", "delete"):
            self.assertIn(f'"{action}"', qml)
        self.assertIn("FloatingWindow {", qml)
        self.assertNotIn("PanelWindow {", qml)
        self.assertIn("parentWindow: root._backingWindow", qml)
        self.assertIn("root.contentItem.QsWindow.window.startSystemMove()", qml)
        self.assertIn('title = "^Blox Theme Picker$"', rules)
        self.assertIn("Choose a wallpaper", rules)
        for control in ("BloxButton", "BloxTextField", "BloxComboBox", "BloxCheckBox", "BloxFontPicker"):
            self.assertIn(control, qml)
        for native_control in ("Button", "TextField", "ComboBox", "CheckBox"):
            self.assertNotRegex(qml, rf"(?m)^\s*{native_control}\s*\{{")
        self.assertIn('"UNSAVED"', qml)
        self.assertIn("colourPickerOpen", qml)
        self.assertIn("openColourPicker", qml)
        self.assertIn('text: "+  New theme"', qml)
        self.assertIn("acceptedButtons: Qt.LeftButton | Qt.RightButton", qml)
        self.assertIn("id: themeActions", qml)
        self.assertIn("id: modalInputBlocker", qml)
        self.assertIn("id: colourInputBlocker", qml)
        self.assertIn("id: modalCardInputBlocker", qml)
        self.assertIn("id: colourCardInputBlocker", qml)
        self.assertIn("id: pickerContent", qml)
        self.assertIn("enabled: root.modalKind.length === 0 && !root.colourPickerOpen", qml)
        self.assertIn("function duplicateIdForName(name)", qml)
        self.assertNotIn('placeholderText: "New stable ID"', qml)
        self.assertIn("id: duplicateIdFooter", qml)
        self.assertIn('text: root.duplicateId', qml)
        self.assertIn('color: "transparent"', qml)
        self.assertIn("anchors.margins: 1", qml)
        self.assertIn("radius: 8", qml)
        self.assertNotIn('"Internal ID', qml)
        self.assertIn("id: modalDismissTimer", qml)
        self.assertIn("id: colourDismissTimer", qml)
        self.assertIn('modalKind = "navigate"', qml)
        self.assertIn('modalKind = "delete"', qml)
        self.assertIn("function select(value: string)", qml)
        self.assertIn("Theme.cancelPreview()", qml)
        self.assertNotIn("bash -c", qml)

    def test_custom_controls_are_registered_and_font_rows_preview_their_family(self) -> None:
        shared = REPOSITORY / "quickshell/.config/quickshell/blox/shared"
        qmldir = (shared / "qmldir").read_text(encoding="utf-8")
        for control in ("BloxButton", "BloxTextField", "BloxComboBox", "BloxCheckBox", "BloxFontPicker"):
            self.assertIn(f"{control} 1.0 {control}.qml", qmldir)
        font_picker = (shared / "BloxFontPicker.qml").read_text(encoding="utf-8")
        self.assertIn("TextInput {", font_picker)
        self.assertIn("font.family: modelData", font_picker)
        self.assertIn("filteredFamilies()", font_picker)
        self.assertIn("opensBelow", font_picker)

    def test_cli_normalises_typographic_option_dashes(self) -> None:
        self.assertEqual(["setup", "cursor", "--yes"], cli.normalise_option_dashes(["setup", "cursor", "—-yes"]))
        self.assertEqual(["setup", "cursor", "--yes"], cli.normalise_option_dashes(["setup", "cursor", "——yes"]))
        with mock.patch.object(cli, "run", return_value=(cli.envelope("setup"), 0)) as run, mock.patch.object(cli, "emit"):
            self.assertEqual(0, cli.main(["setup", "cursor", "—-yes", "--json"]))
        parsed = run.call_args.args[0]
        self.assertEqual("cursor", parsed.feature)
        self.assertTrue(parsed.yes)

    def test_vicinae_scripts_are_shell_safe_and_cover_quick_actions(self) -> None:
        scripts = REPOSITORY / "vicinae/.local/share/vicinae/scripts"
        names = sorted(path.name for path in scripts.glob("*.sh"))
        self.assertEqual(["apply-theme.sh", "create-theme-from-wallpaper.sh", "open-theme-picker.sh"], names)
        for path in scripts.glob("*.sh"):
            text = path.read_text(encoding="utf-8")
            self.assertIn("@vicinae.schemaVersion 1", text)
            self.assertNotIn("eval ", text)
            self.assertTrue(os.access(path, os.X_OK))
        settings_text = (REPOSITORY / "vicinae/.config/vicinae/settings.json").read_text(encoding="utf-8")
        settings = json.loads("\n".join(line for line in settings_text.splitlines() if not line.lstrip().startswith("//")))
        configured = settings["providers"]["scripts"]["preferences"]["customDirs"]
        self.assertEqual([str(scripts)], configured)

    def test_theme_picker_desktop_fallbacks_are_discoverable(self) -> None:
        applications = REPOSITORY / "applications/.local/share/applications"
        launchers = sorted(applications.glob("blox-theme-*.desktop"))
        self.assertEqual(["blox-theme-from-wallpaper.desktop", "blox-theme-picker.desktop"], [path.name for path in launchers])
        for launcher in launchers:
            text = launcher.read_text(encoding="utf-8")
            self.assertIn("Type=Application", text)
            self.assertIn("quickshell ipc -c blox call themePicker", text)


if __name__ == "__main__":
    unittest.main()
