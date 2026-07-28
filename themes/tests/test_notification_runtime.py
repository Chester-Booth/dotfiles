from __future__ import annotations

import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]


class NotificationRuntimeTests(unittest.TestCase):
    def test_shared_notification_images_use_a_left_thumbnail(self) -> None:
        content = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/shared/NotificationContent.qml"
        ).read_text(encoding="utf-8")

        row = content.split("id: notificationRow", 1)[1].split("Flow {", 1)[0]
        self.assertIn("id: notificationThumbnail", row)
        self.assertIn("width: visible ? 72 : 0", row)
        self.assertIn("height: visible ? 72 : 0", row)
        self.assertIn("fillMode: Image.PreserveAspectFit", row)
        self.assertIn(
            "width: parent.width - notificationThumbnail.width - parent.spacing", row
        )
        self.assertNotIn("Math.min(150", content)
        self.assertNotIn("Image.PreserveAspectCrop", content)

    def test_toast_bounds_match_the_visible_card(self) -> None:
        stack = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/popouts/NotificationToastStack.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("width: toastWidth", stack)
        self.assertIn("height: implicitHeight", stack)
        self.assertIn("x: 0", stack)
        self.assertNotIn("width: visibleWidth + dismissTravel", stack)
        self.assertNotIn("x: root.dismissTravel + root.sidePadding", stack)

    def test_position_preview_uses_a_real_desktop_notification(self) -> None:
        bar = (
            REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml"
        ).read_text(encoding="utf-8")
        preview = bar.split(
            "function onNotificationPositionPreviewRequested()", 1
        )[1].split("target: Theme", 1)[0]

        self.assertIn('Quickshell.execDetached(["notify-send"', preview)
        self.assertIn('"Previewing " + Theme.notificationPosition', preview)
        self.assertNotIn("notificationPositionPreviewWindow", bar)

    def test_full_screen_toast_surface_only_accepts_input_on_the_stack(self) -> None:
        bar = (
            REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml"
        ).read_text(encoding="utf-8")
        toast_window = bar.split("id: notificationToastWindow", 1)[1].split(
            "SystemClock {", 1
        )[0]

        self.assertIn("implicitWidth: modelData ? modelData.width : 1", toast_window)
        self.assertIn("implicitHeight: modelData ? modelData.height : 1", toast_window)
        self.assertIn("left: true", toast_window)
        self.assertIn("right: true", toast_window)
        self.assertIn("mask: Region {", toast_window)
        self.assertIn("x: notificationToasts.x", toast_window)
        self.assertIn("y: notificationToasts.y", toast_window)
        self.assertIn("width: notificationToasts.width", toast_window)
        self.assertIn("height: notificationToasts.height", toast_window)
        self.assertNotIn("item: notificationToasts", toast_window)
        self.assertIn("x: notificationToastWindow.onLeft ? 12 + Theme.notificationOffsetX", toast_window)
        self.assertIn("y: notificationToastWindow.onTop ? 12 + Theme.notificationOffsetY", toast_window)
        self.assertNotIn("anchors.left: notificationToastWindow.onLeft", toast_window)


if __name__ == "__main__":
    unittest.main()
