from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "bin" / "floating_sudo"
loader = importlib.machinery.SourceFileLoader("floating_sudo", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
floating_sudo = importlib.util.module_from_spec(spec)
loader.exec_module(floating_sudo)


class ParseRequestTests(unittest.TestCase):
    def test_valid_request(self):
        request = floating_sudo.parse_request(
            "sudo pacman -S obs-studio\nNeeded for recording.\nRisk level: low",
            ["pacman", "-S", "obs-studio"],
        )
        self.assertEqual(request["command"], ["pacman", "-S", "obs-studio"])

    def test_quoted_argument(self):
        request = floating_sudo.parse_request(
            "sudo printf '%s\\n' 'two words'\nPrint test text.\nRisk level: low",
            ["printf", "%s\\n", "two words"],
        )
        self.assertEqual(request["display"], "sudo printf '%s\\n' 'two words'")

    def test_extra_reason_lines_are_kept(self):
        request = floating_sudo.parse_request(
            "sudo true\nFirst line.\nSecond line.\nRisk level: medium", ["true"]
        )
        self.assertEqual(request["reason"], "First line.\nSecond line.")

    def test_rejects_bad_requests(self):
        bad_requests = [
            ("sudo true\r\nReason.\r\nRisk level: low", ["true"]),
            ("sudo true\n\nRisk level: low", ["true"]),
            ("sudo true\nReason.\nRisk level: severe", ["true"]),
            ("sudo true\nReason.\nRisk level: low", ["false"]),
            ("sudo sudo true\nReason.\nRisk level: low", ["sudo", "true"]),
        ]
        for description, command in bad_requests:
            with self.subTest(description=description, command=command):
                with self.assertRaises(floating_sudo.RequestError):
                    floating_sudo.parse_request(description, command)


class ChildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.request_path = Path(self.directory.name) / "request.json"
        self.request_path.write_text(
            json.dumps(
                {
                    "display": "sudo true",
                    "command": ["true"],
                    "reason": "Harmless test.",
                    "risk": "low",
                }
            )
        )

    def tearDown(self):
        self.directory.cleanup()

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="")
    def test_default_rejects_without_sudo(self, _input, _notify):
        with mock.patch.object(floating_sudo.subprocess, "run") as run:
            self.assertEqual(floating_sudo.child(self.request_path), 125)
            run.assert_not_called()

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="Y")
    def test_approval_relays_exit_status(self, _input, _notify):
        completed = mock.Mock(returncode=7)
        with mock.patch.object(
            floating_sudo.subprocess, "run", return_value=completed
        ) as run:
            self.assertEqual(floating_sudo.child(self.request_path), 7)
            run.assert_called_once_with(
                ["/usr/bin/sudo", "--", "true"], check=False
            )

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="y")
    def test_signal_uses_shell_exit_convention(self, _input, _notify):
        with mock.patch.object(
            floating_sudo.subprocess, "run", return_value=mock.Mock(returncode=-15)
        ):
            self.assertEqual(floating_sudo.child(self.request_path), 143)

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value=" y ")
    def test_approval_ignores_outer_space(self, _input, _notify):
        with mock.patch.object(
            floating_sudo.subprocess, "run", return_value=mock.Mock(returncode=0)
        ):
            self.assertEqual(floating_sudo.child(self.request_path), 0)

    def test_result_is_private_and_atomic(self):
        result = Path(self.directory.name) / "result.json"
        floating_sudo.atomic_json(result, {"code": 0})
        self.assertEqual(stat.S_IMODE(result.stat().st_mode), 0o600)
        self.assertEqual(json.loads(result.read_text()), {"code": 0})
        self.assertEqual(list(result.parent.glob(".*.tmp")), [])


class ParentTests(unittest.TestCase):
    def test_missing_gui_fails_closed(self):
        description = "sudo true\nHarmless test.\nRisk level: low"
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(floating_sudo.parent(description, ["true"]), 125)

    def test_cancel_cleans_private_directory(self):
        description = "sudo true\nHarmless test.\nRisk level: low"
        with tempfile.TemporaryDirectory() as runtime:
            environment = {"XDG_RUNTIME_DIR": runtime, "WAYLAND_DISPLAY": "wayland-1"}
            process = mock.Mock()
            process.wait.return_value = 125
            with (
                mock.patch.dict(os.environ, environment, clear=True),
                mock.patch.object(
                    Path,
                    "is_file",
                    autospec=True,
                    side_effect=lambda path: path
                    in (floating_sudo.KITTY, floating_sudo.SUDO),
                ),
                mock.patch.object(
                    floating_sudo.subprocess, "Popen", return_value=process
                ),
            ):
                self.assertEqual(floating_sudo.parent(description, ["true"]), 125)
            self.assertEqual(list(Path(runtime).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
