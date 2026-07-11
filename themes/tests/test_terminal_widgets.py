from __future__ import annotations

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
HELPER = REPOSITORY / "quickshell/.config/quickshell/blox/scripts/overlays/terminal-frame.py"
SPEC = importlib.util.spec_from_file_location("terminal_frame", HELPER)
assert SPEC and SPEC.loader
terminal_frame = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(terminal_frame)


class AnsiScreenTests(unittest.TestCase):
    def test_cursor_motion_erase_and_styling_produce_plain_frame(self) -> None:
        screen = terminal_frame.AnsiScreen(4, 12)
        screen.feed(b"first\r\nsecond\x1b[1;1H\x1b[31mNEW\x1b[0m\x1b[2;4H\x1b[K")
        self.assertEqual("NEWst\nsec", screen.text())

    def test_clear_screen_discards_previous_frame(self) -> None:
        screen = terminal_frame.AnsiScreen(3, 10)
        screen.feed(b"old frame\x1b[2J\x1b[2;3Hnew")
        self.assertEqual("\n  new", screen.text())

    def test_background_coloured_spaces_remain_visible(self) -> None:
        screen = terminal_frame.AnsiScreen(2, 6)
        screen.feed(b"\x1b[42m   \x1b[49m ")
        self.assertEqual("███", screen.text())


class TerminalWidgetSafetyTests(unittest.TestCase):
    def test_only_known_presets_can_be_resolved(self) -> None:
        self.assertEqual(("tty-clock", "-c"), terminal_frame.command_for("clock"))
        self.assertEqual(("tty-clock", "-c", "-s"), terminal_frame.command_for("clock", "tty-clock -c -s"))
        with self.assertRaisesRegex(ValueError, "must run tty-clock"):
            terminal_frame.command_for("clock", "sh -c 'tty-clock; touch /tmp/nope'")
        with self.assertRaisesRegex(ValueError, "unsupported"):
            terminal_frame.command_for("custom; rm -rf -- /tmp/example")

    def test_capture_uses_argument_vector_and_bounded_process_group(self) -> None:
        fake_process = mock.Mock(pid=1234)
        fake_process.poll.return_value = 0
        with mock.patch.object(terminal_frame.pty, "openpty", return_value=(10, 11)), \
             mock.patch.object(terminal_frame.termios, "tcsetwinsize"), \
             mock.patch.object(terminal_frame.os, "close"), \
             mock.patch.object(terminal_frame.subprocess, "Popen", return_value=fake_process) as popen, \
             mock.patch.object(terminal_frame.select, "select", return_value=([], [], [])):
            terminal_frame.capture(("tty-clock", "-c"), 20, 60, 0.0001, 100)
        self.assertEqual(("tty-clock", "-c"), popen.call_args.args[0])
        self.assertNotIn("shell", popen.call_args.kwargs)
        self.assertTrue(popen.call_args.kwargs["start_new_session"])

    def test_missing_dependency_is_a_user_facing_frame(self) -> None:
        completed = subprocess.run([str(HELPER), "clock", "--duration-ms", "50"], check=True, text=True, capture_output=True)
        self.assertTrue(completed.stdout.strip())


if __name__ == "__main__":
    unittest.main()
