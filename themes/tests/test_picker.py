from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
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

    def test_generated_target_files_can_be_exported_without_path_escape(self) -> None:
        state = self.root / "state"
        generated = state / "current/code/themes/blox-dark-2026.json"
        generated.parent.mkdir(parents=True)
        generated.write_text('{"name":"Blox"}', encoding="utf-8")
        output = self.root / "downloads/blox-dark-2026.json"
        with mock.patch("blox_theme.cli.state_dir", return_value=state):
            response, code = self.invoke("export-target", "code", "--file", "code/themes/blox-dark-2026.json", "--output", str(output), "--json")
            self.assertEqual(0, code, response)
            self.assertEqual('{"name":"Blox"}', output.read_text(encoding="utf-8"))

            response, code = self.invoke("export-target", "code", "--file", "../outside", "--output", str(self.root / "outside"), "--json")
            self.assertEqual(3, code)
            self.assertIn("not a generated file", response["errors"][0])

    def test_generated_target_files_can_be_exported_as_one_zip(self) -> None:
        state = self.root / "state"
        expected = {
            "code/settings.json": "settings",
            "code/package.json": "package",
            "code/themes/blox-dark-2026.json": "theme",
        }
        for name, content in expected.items():
            generated = state / "current" / name
            generated.parent.mkdir(parents=True, exist_ok=True)
            generated.write_text(content, encoding="utf-8")
        output = self.root / "downloads/code-generated-files.zip"
        with mock.patch("blox_theme.cli.state_dir", return_value=state):
            response, code = self.invoke("export-target", "code", "--archive", "--output", str(output), "--json")
        self.assertEqual(0, code, response)
        self.assertTrue(response["data"]["archive"])
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(set(expected), set(archive.namelist()))
            for name, content in expected.items():
                self.assertEqual(content, archive.read(name).decode("utf-8"))


class PickerIntegrationSourceTests(unittest.TestCase):
    def test_quickshell_modules_are_registered_for_live_reload(self) -> None:
        modules = REPOSITORY / "quickshell/.config/quickshell/blox/modules"
        registered = {
            line.split()[0]
            for line in (modules / "qmldir").read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        available = {path.stem for path in modules.glob("*.qml")}

        self.assertEqual(available, registered)

    def test_widget_style_selector_preserves_widget_items(self) -> None:
        qml = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml"
        ).read_text(encoding="utf-8")
        setter = qml.split("function setWidgetProfile(value)", 1)[1].split(
            "function setTarget", 1
        )[0]
        widgets = qml.split('visible: root.editorMode === "widgets"', 1)[1].split(
            'text: "List"', 1
        )[0]

        self.assertIn('text: "Style"', widgets)
        self.assertIn('["minimal", "compact", "comfortable"]', widgets)
        self.assertIn("next.widgets.profile = value", setter)
        self.assertNotIn('next.widgets = {\n            "profile": value', setter)

    def test_bar_item_drag_uses_a_moving_proxy(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        self.assertIn("id: barDragProxy", qml)
        self.assertGreaterEqual(qml.count("target: null"), 2)
        self.assertIn("Drag.source: barDragProxy", qml)
        self.assertNotIn("Drag.source: barItemRow", qml)
        drag_section = qml.split('model: ["start", "centre", "end", "hidden"]', 1)[1].split('text: "Bar"', 1)[0]
        self.assertIn("onPositionChanged:", drag_section)
        self.assertIn("root.finishBarDrag()", drag_section)
        self.assertIn("root.setBarDropTarget", drag_section)
        self.assertIn('color: Theme.blue', drag_section)
        self.assertIn("z: 1000", qml)
        self.assertEqual(1, qml.count("id: barDragProxy"))

    def test_picker_uses_json_api_and_has_confirmation_paths(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        rules = (REPOSITORY / "hyprland/.config/hypr/conf.d/rules.lua").read_text(encoding="utf-8")
        for action in ("list", "show", "preview", "generate", "save", "apply", "duplicate", "rename", "delete"):
            self.assertIn(f'"{action}"', qml)
        self.assertIn("FloatingWindow {", qml)
        self.assertNotIn("PanelWindow {", qml)
        self.assertIn("parentWindow: root._backingWindow", qml)
        self.assertIn("visible: open && !widgetEditModePending", qml)
        self.assertIn("hideTimer.stop()", qml)
        self.assertIn("Theme.widgetEditModeCancelRequested()", qml)
        self.assertIn("hl.dsp.focus({ workspace = \\\"previous\\\" })", qml)
        self.assertIn("function recoverPickerWorkspace(returnWorkspace)", qml)
        self.assertIn("hl.dsp.window.move({ workspace =", qml)
        self.assertIn('window = \\\\\\\"title:^Blox Theme Picker$\\\\\\\"', qml)
        self.assertNotIn("hyprctl dispatch movetoworkspacesilent", qml)
        self.assertIn('recoverPickerWorkspace("");', qml)
        self.assertIn("recoverPickerWorkspace(returnWorkspace);", qml)
        self.assertIn("root._backingWindow.requestActivate()", qml)
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
        self.assertIn('iconName: "plus"', qml)
        self.assertIn('text: "New theme"', qml)
        self.assertIn("function openNewTheme(wallpaperPage)", qml)
        self.assertIn('runApi("new-template", ["show", "blox-panel"])', qml)
        self.assertIn('text: "From blank"', qml)
        self.assertIn('text: "From wallpaper"', qml)
        self.assertIn("Layout.rightMargin: 10", qml)
        self.assertIn('text: "Wallpaper"', qml)
        self.assertNotIn('text: "Generate"', qml)
        self.assertIn("acceptedButtons: Qt.LeftButton | Qt.RightButton", qml)
        self.assertIn("id: themeActions", qml)
        self.assertIn("id: modalInputBlocker", qml)
        self.assertIn("id: colourInputBlocker", qml)
        self.assertIn("id: modalCardInputBlocker", qml)
        self.assertIn("id: colourCardInputBlocker", qml)
        self.assertIn("id: pickerContent", qml)
        self.assertIn('root.action === "preview-edit"', qml)
        self.assertIn("function duplicateIdForName(name)", qml)
        self.assertNotIn('placeholderText: "New stable ID"', qml)
        self.assertIn("id: duplicateIdFooter", qml)
        self.assertIn('root.modalKind === "new" ? root.newThemeId : root.duplicateId', qml)
        self.assertIn('color: "transparent"', qml)
        self.assertIn("anchors.margins: 1", qml)
        self.assertIn("radius: 8", qml)
        self.assertNotIn('"Internal ID', qml)
        self.assertIn("id: modalDismissTimer", qml)
        self.assertIn("id: colourDismissTimer", qml)
        self.assertIn('showModal("navigate")', qml)
        self.assertIn('showModal("delete")', qml)
        self.assertIn("onClicked: themeActions.open()", qml)
        self.assertNotIn("onClicked: {\n                                                if (modelData.id !== root.selectedId)\n                                                    root.requestSelection", qml)
        self.assertIn("function select(value: string)", qml)
        self.assertIn("Theme.cancelPreview()", qml)
        self.assertNotIn("bash -c", qml)

    def test_picker_rejects_stale_requests_and_keeps_applied_identity_separate(self) -> None:
        picker = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        theme = (REPOSITORY / "quickshell/.config/quickshell/blox/shared/Theme.qml").read_text(encoding="utf-8")
        self.assertIn("property var activeRequest: null", picker)
        self.assertIn('"candidateRevision": candidateRevision', picker)
        self.assertIn('"candidateJson": candidate === null ? "" : JSON.stringify(candidate)', picker)
        self.assertIn("request.sessionRevision !== root.sessionRevision", picker)
        self.assertIn("request.candidateRevision !== candidateRevision", picker)
        self.assertIn("Theme.previewSource(JSON.parse(request.candidateJson))", picker)
        self.assertIn("validationPending = true", picker)
        self.assertIn("root.continueQueuedGeneration()", picker)
        self.assertIn('runApi("show-generate-current", ["show", Theme.activeThemeId])', picker)
        self.assertIn('if (busy && action !== "preview-edit")', picker)
        self.assertIn('return "busy"', picker)
        self.assertIn("return root.requestClose()", picker)
        self.assertNotIn("candidate.wallpaper.path);\n            }\n            return \"open-generating\"", picker)
        self.assertIn('property string activeThemeId: "blox-panel"', theme)
        self.assertIn("activeThemeId = data.id", theme)
        preview = theme.split("function previewSource", 1)[1].split("function cancelPreview", 1)[0]
        self.assertNotIn("activeThemeId =", preview)
        self.assertIn("root.loadActiveIdentity(text())", theme)

    def test_unavailable_targets_are_visible_but_not_editable(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        self.assertIn('readonly property var unavailableTargetKeys: ["sddm", "grub"]', qml)
        self.assertIn("function targetAvailable(key)", qml)
        advanced = qml.split('visible: root.editorMode === "advanced"', 1)[1].split('visible: root.editorMode === "widgets"', 1)[0]
        self.assertNotIn('text: "Widget profile"', advanced)
        self.assertIn('return key + " · unavailable"', qml)
        self.assertIn("if (!targetAvailable(key))", qml)
        self.assertIn("enabled: root.targetAvailable(modelData)", qml)
        self.assertIn('readonly property var coreTargetKeys:', qml)
        self.assertIn('readonly property var applicationTargetKeys:', qml)
        self.assertIn('text: "Core"', qml)
        self.assertIn('text: "Applications"', qml)

    def test_creation_and_application_flows_expose_progress_and_apply_modes(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        for label in ("Name", "File Path", "Browse", "Base Colour Palette", "Matugen", "Pywal"):
            self.assertIn(f'"{label}"', qml)
        self.assertIn('runApi("palette", ["palette", path])', qml)
        self.assertIn('"wallpaper": wallpaper', qml)
        self.assertIn('"backend": backend', qml)
        self.assertIn("request.inputs", qml)
        self.assertIn("request.inputs.paletteSerial !== paletteRequestSerial", qml)
        self.assertIn("request.inputs.wallpaper !== newWallpaper.trim()", qml)
        self.assertIn('showModal("progress")', qml)
        self.assertIn('text: "Guide"', qml)
        self.assertIn('if (key === "stylus" || key === "obsidian")', qml)
        self.assertIn('return "manual"', qml)
        self.assertIn('key === "code" || key === "cursor_editor" ? "Reload Window"', qml)
        self.assertIn('source: "../assets/stylus-import.png"', qml)
        self.assertIn('text: "Generated Files"', qml)
        self.assertIn("function generatedFiles()", qml)
        self.assertIn('const order = ["stylus"]', qml)
        self.assertIn("function generatedFileGroups()", qml)
        self.assertIn('text: "Download all (.zip)"', qml)
        self.assertIn("root.downloadGeneratedArchive(modelData.target)", qml)
        self.assertIn("root.downloadGeneratedFile(modelData.target, modelData.file)", qml)
        self.assertIn("Install and select the Minimal theme", qml)
        self.assertIn("generated style-settings.json", qml)
        self.assertIn('text: "Simple"', qml)
        simple = qml.split('visible: root.editorMode === "overview"', 1)[1].split('visible: root.editorMode === "advanced"', 1)[0]
        self.assertNotIn('text: "Target impact"', simple)
        self.assertNotIn('text: "Dependency and compatibility notes"', simple)
        self.assertIn("editorScroll.contentY - delta * 4", qml)
        self.assertIn('text: "Bar / OSD / Notifications"', qml)
        self.assertIn('visible: root.editorMode === "overview"', qml)
        self.assertIn('Theme.osdPositionPreviewRequested()', qml)
        self.assertIn('Theme.notificationPositionPreviewRequested()', qml)

    def test_widget_position_canvas_supports_drag_resize_snap_and_numeric_geometry(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        for expected in (
            'id: widgetCanvas',
            'text: "Position"',
            'drag.target: widgetPreview',
            'cursorShape: Qt.SizeFDiagCursor',
            'root.commitWidgetPreview(',
            'anchor = (bottom ? "bottom-" : "top-") + (right ? "right" : "left")',
            'model: ["offset_x", "offset_y", "width", "height"]',
            'root.updateWidgetGeometry(',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, qml)

    def test_advanced_picker_can_toggle_place_and_reorder_every_bar_item(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        advanced = qml.split('visible: root.editorMode === "advanced"', 1)[1]
        for function_name in (
            "barItems",
            "trayOpensForward",
            "applicationTrayAtStart",
            "normaliseBarItemOrders",
            "setBarItems",
            "setBarItemEnabled",
            "setBarItemDisplay",
            "setBarItemVisibility",
            "setBarItemRegion",
            "moveBarItem",
            "moveBarItemTo",
        ):
            self.assertIn(f"function {function_name}(", qml)
        self.assertIn('model: ["start", "centre", "end", "hidden"]', advanced)
        self.assertIn('"Tray"', advanced)
        self.assertIn("root.setBarItemEnabled(barItemRow.modelData.id, value)", advanced)
        self.assertIn('model: ["click to toggle", "only numeric", "only icon"]', advanced)
        self.assertIn("root.setBarItemDisplay(barItemRow.barItemId, displayValues[index])", advanced)
        self.assertIn('visible: barItemRow.modelData.id === "battery"', advanced)
        self.assertIn('model: ["always visible", "hidden when normal"]', advanced)
        self.assertIn('visible: ["touchpad", "fan", "gpu"].indexOf(barItemRow.modelData.id) >= 0', advanced)
        self.assertIn("Layout.preferredWidth: visible ? 172 : 0", advanced)
        self.assertIn("root.setBarItemVisibility(barItemRow.barItemId, visibilityValues[index])", advanced)
        self.assertIn('"touchpad": "panel-top"', qml)
        self.assertIn("Drag.active: root.barDragActive", qml)
        self.assertEqual(2, advanced.count("target: null"))
        self.assertEqual(2, advanced.count("onTranslationChanged: root.moveBarDragProxy"))
        self.assertIn("Drag.source: barDragProxy", advanced)
        self.assertIn("root.finishBarDrag()", advanced)
        self.assertIn('iconName: "chevron-up"', advanced)
        self.assertIn('iconName: "chevron-down"', advanced)
        self.assertNotIn('ToolTip.text: "Move up"', advanced)
        self.assertNotIn('ToolTip.text: "Move down"', advanced)
        self.assertIn("onClicked: root.moveBarItem(barItemRow.barItemId, -1)", advanced)
        self.assertIn("onClicked: root.moveBarItem(barItemRow.barItemId, 1)", advanced)
        self.assertIn('barItemRow.modelData.id === "application-tray" ? ["tray"]', advanced)
        self.assertIn('barItemRow.modelData.id === "tray" ? ["start", "centre", "end"] : root.barRegions', advanced)
        self.assertIn('if (region === "hidden")', qml)
        self.assertIn('if (region === "start")', qml)
        self.assertIn('if (region === "end")', qml)
        self.assertIn('value === "tray" ? "hidden" : value', advanced)
        normalise = qml.split("function normaliseBarItemOrders(", 1)[1].split("function setBarItems", 1)[0]
        self.assertIn("ordered.push(members[index])", normalise)
        self.assertIn("return ordered", normalise)
        header = advanced.index('text: regionSection.modelData === "hidden" ? "Tray"')
        first_drop_target = advanced.index('"start:" + regionSection.modelData')
        self.assertLess(header, first_drop_target)
        self.assertIn("function scrollBarDrag()", qml)
        self.assertIn("running: root.barDragActive", qml)
        self.assertIn("Theme.resolvedBarItems(overrides, position)", qml)
        self.assertIn("Theme.resolvedBarItems(overrides, value)", qml)
        self.assertIn("Theme.loadShell(next.shell)", qml)
        self.assertIn('if (id === "application-tray")', qml)
        self.assertIn("return !trayOpensForward(items)", qml)
        self.assertIn("Layout.preferredWidth: 92", advanced)

    def test_custom_controls_are_registered_and_font_rows_preview_their_family(self) -> None:
        shared = REPOSITORY / "quickshell/.config/quickshell/blox/shared"
        qmldir = (shared / "qmldir").read_text(encoding="utf-8")
        for control in ("BloxButton", "BloxTextField", "BloxComboBox", "BloxCheckBox", "BloxFontPicker"):
            self.assertIn(f"{control} 1.0 {control}.qml", qmldir)
        self.assertIn("singleton Lucide 1.0 Lucide.qml", qmldir)
        lucide = (shared / "Lucide.qml").read_text(encoding="utf-8")
        button = (shared / "BloxButton.qml").read_text(encoding="utf-8")
        self.assertIn('source: "../assets/fonts/lucide.ttf"', lucide)
        self.assertIn("Lucide.icon(root.iconName)", button)
        self.assertTrue((REPOSITORY / "quickshell/.config/quickshell/blox/assets/fonts/LUCIDE-LICENSE").is_file())
        font_picker = (shared / "BloxFontPicker.qml").read_text(encoding="utf-8")
        self.assertIn("TextInput {", font_picker)
        self.assertIn("font.family: modelData", font_picker)
        self.assertIn("filteredFamilies()", font_picker)
        self.assertIn("opensBelow", font_picker)
        self.assertIn("modal: true", font_picker)
        self.assertIn("property bool suppressEditingFinished: false", font_picker)
        self.assertIn("function chooseHighlighted()", font_picker)
        self.assertIn("Keys.onPressed", font_picker)
        self.assertIn("event.key === Qt.Key_Space", font_picker)
        self.assertIn("required property int index", font_picker)
        self.assertIn("Canvas {", font_picker)
        self.assertNotIn('text: popup.visible ? "▴" : "▾"', font_picker)
        combo_box = (shared / "BloxComboBox.qml").read_text(encoding="utf-8")
        self.assertIn("modal: true", combo_box)
        self.assertNotIn("modal: false", combo_box)
        self.assertIn("signal activated(int index, string text)", combo_box)
        self.assertIn("function moveHighlight(delta)", combo_box)
        self.assertIn("Keys.onPressed", combo_box)
        self.assertNotIn("root.currentIndex = index", combo_box)
        text_field = (shared / "BloxTextField.qml").read_text(encoding="utf-8")
        self.assertIn("signal accepted()", text_field)
        self.assertIn("function focusEditor(selectAllText)", text_field)
        self.assertIn("root.editingFinished();", text_field)

    def test_blank_theme_starts_without_selected_visual_inputs(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        blank = qml.split("function blankTheme(", 1)[1].split("function startNewTheme(", 1)[0]
        self.assertIn('blank.colours[key] = ""', blank)
        self.assertIn('blank.fonts[role] = ""', blank)
        self.assertIn('blank.wallpaper.path = ""', blank)

    def test_simple_mode_contains_font_pickers(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        simple = qml.split('visible: root.editorMode === "overview"', 1)[1].split('visible: root.editorMode === "advanced"', 1)[0]
        self.assertIn('text: "Fonts"', simple)
        self.assertIn("BloxFontPicker {", simple)

    def test_theme_list_uses_source_colours_wallpaper_and_fonts(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        theme_list = qml.split("id: themeList", 1)[1].split("id: editorScroll", 1)[0]
        self.assertIn("id: themeThumbnail", theme_list)
        self.assertIn("modelData.preview.wallpaper", theme_list)
        self.assertIn("modelData.preview.fonts.ui", theme_list)
        self.assertIn("root.themePreviewColour", theme_list)
        self.assertIn("id: themeBarPreview", theme_list)
        self.assertIn("root.themePreviewBarCount", theme_list)
        self.assertIn("fontSizeMode: themeDelegate.previewAtMinimum ? Text.Fit : Text.FixedSize", theme_list)
        self.assertNotIn('text: modelData.unsaved ? "UNSAVED  ·  " + modelData.variant : modelData.variant', theme_list)

    def test_picker_modal_keyboard_and_scroll_affordances_are_explicit(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        escape = qml.split("Keys.onEscapePressed", 1)[1].split("Shortcut {", 1)[0]
        self.assertLess(escape.index("root.dismissColourPicker()"), escape.index("root.dismissModal()"))
        self.assertLess(escape.index("root.dismissModal()"), escape.index("root.requestClose()"))
        for identifier in ("modalFocusScope", "colourFocusScope", "newNameField", "duplicateNameField", "renameNameField", "modalCancelButton", "colourDoneButton", "colourHexField"):
            self.assertIn(f"id: {identifier}", qml)
        self.assertIn("function rememberOverlayFocus()", qml)
        self.assertIn("function restoreOverlayFocus()", qml)
        self.assertIn("function modalConfirmationEnabled()", qml)
        self.assertGreaterEqual(qml.count("ScrollBar.vertical: ScrollBar"), 2)
        self.assertIn("policy: ScrollBar.AlwaysOn", qml)
        self.assertIn("contentWidth: width", qml)
        semantic = qml.split("id: semanticSwatch", 1)[1].split("text: \"Terminal palette\"", 1)[0]
        self.assertIn("wrapMode: Text.WordWrap", semantic)
        self.assertIn("maximumLineCount: 2", semantic)
        self.assertNotIn("elide: Text.ElideRight", semantic)

    def test_picker_exposes_safe_import_and_export_workflows(self) -> None:
        qml = (REPOSITORY / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        self.assertIn('root.runApi("import", ["import", path]);', qml)
        self.assertIn('const args = ["export", root.candidate.id, "--output", path];', qml)
        self.assertIn('args.push("--include-wallpaper");', qml)
        self.assertIn('runApi("list-after-import", ["list"]);', qml)
        self.assertIn("Apply remains a separate action", qml)
        self.assertIn("fileMode: FileDialog.SaveFile", qml)
        self.assertIn("enabled: !root.dirty && !root.busy", qml)
        self.assertNotIn("preview.svg", qml)

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
        script_provider = settings["providers"]["scripts"]
        self.assertTrue(script_provider["enabled"])
        self.assertNotIn("preferences", script_provider)

        apply_script = scripts / "apply-theme.sh"
        missing_argument = subprocess.run(
            [str(apply_script)],
            cwd=REPOSITORY,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(2, missing_argument.returncode)
        self.assertEqual("Usage: apply-theme.sh <theme-id>\n", missing_argument.stderr)

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
