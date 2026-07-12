from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PICKER = ROOT / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml"


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

    def test_preview_has_wallpaper_bar_selection_and_edge_resize(self) -> None:
        self.assertIn("id: widgetCanvas", self.source)
        self.assertIn("id: barPreview", self.source)
        self.assertIn('model: root.barPreviewItems("start")', self.source)
        self.assertIn('model: root.barPreviewItems("centre")', self.source)
        self.assertIn('model: root.barPreviewItems("end")', self.source)
        self.assertIn("text: root.barPreviewGlyph(parent.modelData.id)", self.source)
        self.assertIn('root.selectedWidgetIndex = -1', self.source)
        self.assertIn('text: "Automatic size"', self.source)
        self.assertGreaterEqual(self.source.count("cursorShape: Qt.SizeHorCursor"), 2)
        self.assertGreaterEqual(self.source.count("cursorShape: Qt.SizeVerCursor"), 2)


if __name__ == "__main__":
    unittest.main()
