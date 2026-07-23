from __future__ import annotations

import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]


class OsdRuntimeTests(unittest.TestCase):
    def test_osd_surface_is_bounded_and_click_through(self) -> None:
        source = (
            REPOSITORY / "quickshell/.config/quickshell/blox/modules/Osd.qml"
        ).read_text(encoding="utf-8")
        window = source.split("id: osdWindow", 1)[1]

        self.assertIn("implicitWidth: 292 +", window)
        self.assertIn("implicitHeight: 72 + restingGap", window)
        self.assertIn("y: osdWindow.onTop ? osdWindow.restingGap : 0", window)
        self.assertIn("-osdCard.height - osdCard.y", window)
        self.assertIn("osdWindow.height - osdCard.y", window)
        self.assertNotIn("modelData.width", window)
        self.assertNotIn("modelData.height", window)
        self.assertIn("left: onLeft", window)
        self.assertIn("right: onRight", window)
        self.assertIn("mask: Region {\n            }", window)

    def test_position_preview_uses_a_numeric_duration(self) -> None:
        source = (
            REPOSITORY / "quickshell/.config/quickshell/blox/modules/Osd.qml"
        ).read_text(encoding="utf-8")

        self.assertIn('"󰍹", "info", 1400);', source)
        self.assertNotIn('"󰍹", "info", "1400");', source)


if __name__ == "__main__":
    unittest.main()
