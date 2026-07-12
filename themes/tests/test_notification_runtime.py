from __future__ import annotations

import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]


class NotificationRuntimeTests(unittest.TestCase):
    def test_toast_bounds_match_the_visible_card(self) -> None:
        stack = (
            REPOSITORY
            / "quickshell/.config/quickshell/blox/popouts/NotificationToastStack.qml"
        ).read_text(encoding="utf-8")

        self.assertIn("width: toastWidth", stack)
        self.assertIn("x: 0", stack)
        self.assertNotIn("width: visibleWidth + dismissTravel", stack)
        self.assertNotIn("x: root.dismissTravel + root.sidePadding", stack)

    def test_position_preview_uses_the_runtime_toast_stack(self) -> None:
        bar = (
            REPOSITORY / "quickshell/.config/quickshell/blox/modules/Bar.qml"
        ).read_text(encoding="utf-8")
        preview = bar.split("id: notificationPositionPreviewWindow", 1)[1].split(
            "UiState {", 1
        )[0]

        self.assertIn("NotificationToastStack {", preview)
        self.assertIn('"summary": "Notification position"', preview)
        self.assertIn("position: Theme.notificationPosition", preview)
        self.assertNotIn('text: "Previewing " + Theme.notificationPosition', preview)


if __name__ == "__main__":
    unittest.main()
