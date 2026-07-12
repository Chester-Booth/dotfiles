from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class WidgetRuntimeSourceTests(unittest.TestCase):
    def test_normal_overlay_uses_shared_renderer(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/EwwOverlays.qml").read_text(encoding="utf-8")
        self.assertIn("Shared.DesktopWidget {", source)
        self.assertNotIn("component OverlayBox", source)
        self.assertIn('modelData.visibility !== "empty-workspace" || root.activeWorkspaceEmpty()', source)
        self.assertIn("visible: !root.editMode", source)

    def test_renderer_honours_auto_size_and_terminal_monospace(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/shared/DesktopWidget.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property bool autoSize", source)
        self.assertIn("autoSize ? 0 : Number(widget.width", source)
        self.assertIn("root.terminalPreset ? Theme.monoFontFamily", source)

    def test_widget_file_changes_reload_the_widget_profile(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/shared/Theme.qml").read_text(encoding="utf-8")
        widget_file = source.split("id: widgetFile", 1)[1]
        self.assertIn("onFileChanged", widget_file)
        self.assertIn("reloadWidgets();", widget_file)
        self.assertNotIn("\n                reload();", widget_file)

    def test_theme_preview_uses_candidate_widget_items(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/shared/Theme.qml").read_text(encoding="utf-8")
        preview = source.split("function previewSource", 1)[1].split("function cancelPreview", 1)[0]
        self.assertIn("widgetItems = data.widgets.items;", preview)

    def test_new_widgets_default_to_empty_workspace_visibility(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/ThemePicker.qml").read_text(encoding="utf-8")
        draft = source.split("function newWidgetDraft", 1)[1].split("function widgetPreset", 1)[0]
        self.assertIn('"visibility": "empty-workspace"', draft)


if __name__ == "__main__":
    unittest.main()
