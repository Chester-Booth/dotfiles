from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class WidgetRuntimeSourceTests(unittest.TestCase):
    def test_normal_overlay_uses_shared_renderer(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/DesktopWidgets.qml").read_text(encoding="utf-8")
        self.assertIn("Shared.DesktopWidget {", source)
        self.assertIn("renderUpdates: widgetWindow.visible", source)
        self.assertNotIn("component OverlayBox", source)
        self.assertIn('modelData.visibility !== "empty-workspace" || root.activeWorkspaceEmpty()', source)
        self.assertIn("visible: !root.editMode", source)
        self.assertIn("root.run(root.commandFor", source)
        self.assertIn("onTriggered: widgetRenderer.refresh()", source)

    def test_renderer_honours_auto_size_background_opacity_and_terminal_monospace(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/shared/DesktopWidget.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property bool autoSize", source)
        self.assertIn("readonly property real widgetScale", source)
        self.assertIn("readonly property real backgroundOpacity", source)
        self.assertIn("widget.options.background_opacity !== undefined", source)
        self.assertIn("Theme.withAlpha(widget.type ===", source)
        self.assertIn("root.backgroundOpacity", source)
        self.assertIn("Theme.widgetFontSize * root.widgetScale", source)
        self.assertIn("autoSize ? 0 : Number(widget.width", source)
        self.assertIn("root.terminalPreset ? Theme.monoFontFamily", source)
        self.assertIn('"--stream"', source)
        self.assertIn("readonly property bool streamedTerminalPreset: terminalPreset", source)
        self.assertIn("readonly property bool persistentTerminalPreset", source)
        self.assertIn('widget.type === "music" ? 16', source)
        self.assertIn('widget.type === "aquarium" || widget.type === "clock" ? 500', source)
        self.assertIn('command.push("--plain")', source)
        self.assertNotIn('command.push("--settle-ms"', source)
        self.assertIn("lineHeightMode: root.widget.type", source)
        self.assertIn('root.widget.type === "clock" ? 1000', source)
        self.assertIn('root.widget.type === "clock" ? (root.clockFrame.length > 0', source)
        self.assertIn('root.widget.type !== "clock" && root.widget.type !== "music" ? Text.RichText : Text.PlainText', source)
        self.assertIn("stdout: SplitParser", source)
        self.assertIn('root.widget.type === "clock"', source)
        self.assertIn("root.clockFrame = frame", source)
        self.assertIn("Text.RichText", source)
        self.assertIn('widget.type === "aquarium" ? "#1d2021"', source)

    def test_clock_uses_an_atomic_canvas_frame(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/shared/DesktopWidget.qml").read_text(encoding="utf-8")
        self.assertIn('property string clockFrame: ""', source)
        self.assertIn("renderTarget: Canvas.Image", source)
        self.assertIn("context.clearRect(0, 0, width, height)", source)
        self.assertIn("context.fillRect(0, 0, width, height)", source)
        self.assertIn('if (character === "█")', source)
        self.assertIn("clockCanvas.requestPaint()", source)

    def test_widget_edit_mode_persists_auto_size_scale_and_background_opacity(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/WidgetEditMode.qml").read_text(encoding="utf-8")
        self.assertIn("function selectedAutoSize()", source)
        self.assertIn("selectedItem.options.auto_size", source)
        self.assertIn('options.scale = Math.max(0.25, Math.min(4', source)
        self.assertIn('text: "Transparency"', source)
        self.assertIn('suffix: "%"', source)
        self.assertIn("const transparency = Math.max(0, Math.min(100", source)
        self.assertIn("options.background_opacity = 1 - transparency / 100", source)
        self.assertIn("width: root.selectedItem ? 300", source)

    def test_widget_edit_mode_returns_to_its_origin_workspace(self) -> None:
        overlays = (ROOT / "quickshell/.config/quickshell/blox/modules/DesktopWidgets.qml").read_text(encoding="utf-8")
        theme = (ROOT / "quickshell/.config/quickshell/blox/shared/Theme.qml").read_text(encoding="utf-8")
        self.assertIn('property string editReturnWorkspace: ""', overlays)
        self.assertIn("Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id)", overlays)
        self.assertIn('returnWorkspace || "previous"', overlays)
        self.assertEqual(2, overlays.count("Theme.widgetEditModeFinished("))
        self.assertIn("signal widgetEditModeFinished(string widgetsJson, string returnWorkspace)", theme)

    def test_custom_actions_launch_detached_and_refresh_afterwards(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/DesktopWidgets.qml").read_text(encoding="utf-8")
        self.assertIn("root.run(root.commandFor(widgetWindow.modelData.left_click_command))", source)
        self.assertIn("root.run(root.commandFor(widgetWindow.modelData.right_click_command))", source)
        self.assertIn("actionRefresh.restart()", source)
        self.assertNotIn("widgetAction.run", source)

    def test_widget_input_is_limited_to_the_visible_renderer(self) -> None:
        source = (ROOT / "quickshell/.config/quickshell/blox/modules/DesktopWidgets.qml").read_text(encoding="utf-8")
        widget_window = source.split("id: widgetWindow", 1)[1].split("WidgetEditMode {", 1)[0]
        self.assertIn("mask: Region {", widget_window)
        self.assertIn("item: widgetRenderer", widget_window)

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
