from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PICKER = ROOT / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml"
EDIT_MODE = ROOT / "quickshell/.config/quickshell/blox/modules/WidgetEditMode.qml"


class WidgetPickerSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = PICKER.read_text(encoding="utf-8")

    def test_widget_editor_uses_grouped_content_specific_presets(self) -> None:
        self.assertIn('model: ["file", "music", "calendar", "clock", "decorative", "custom"]', self.source)
        self.assertIn('model: ["aquarium", "pipes", "tree", "matrix", "fortune", "train"]', self.source)
        self.assertIn('text: "Clock options"', self.source)
        self.assertIn('text: "File options"', self.source)
        self.assertNotIn('root.modalKind === "widget" ? 620', self.source)

    def test_new_widgets_are_inserted_first_and_editor_excludes_geometry(self) -> None:
        self.assertIn("items.unshift(widgetDraft);", self.source)
        modal = self.source.split('visible: root.modalKind === "widget"', 1)[1].split("id: duplicateNameField", 1)[0]
        self.assertNotIn('text: "Position"', modal)
        self.assertNotIn('text: "Shape"', modal)

    def test_picker_launches_real_widget_edit_mode(self) -> None:
        self.assertIn('text: "Edit mode"', self.source)
        self.assertIn("Theme.widgetEditModeRequested();", self.source)
        self.assertIn("onWidgetEditModeFinished", self.source)
        edit_mode = EDIT_MODE.read_text(encoding="utf-8")
        self.assertIn("Shared.DesktopWidget {", edit_mode)
        self.assertIn("property int selectedIndex", edit_mode)
        self.assertIn('text: "Automatic size"', edit_mode)
        self.assertIn('text: "Visibility"', edit_mode)
        self.assertGreaterEqual(edit_mode.count("Qt.SizeHorCursor"), 1)
        self.assertGreaterEqual(edit_mode.count("Qt.SizeVerCursor"), 1)


if __name__ == "__main__":
    unittest.main()
