from __future__ import annotations

from contextlib import redirect_stdout
import importlib.machinery
import importlib.util
import io
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
    def test_help_documents_the_full_call_contract(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(floating_sudo.main(["floating_sudo", "--help"]), 0)
        help_text = output.getvalue()
        self.assertIn("command > what > why", help_text)
        self.assertIn("one description line per command or package", help_text)
        self.assertIn("Risk level: level > reasoning", help_text)
        self.assertIn("without a leading sudo", help_text)

    def test_valid_request(self):
        request = floating_sudo.parse_request(
            "sudo pacman -S obs-studio\npacman -S obs-studio > Install OBS Studio > Record the demo\nRisk level: low > It comes from the configured package source",
            ["pacman", "-S", "obs-studio"],
        )
        self.assertEqual(request["command"], ["pacman", "-S", "obs-studio"])

    def test_quoted_argument(self):
        request = floating_sudo.parse_request(
            "sudo printf '%s\\n' 'two words'\nprintf > Print test text > Check quoted arguments\nRisk level: low > It only writes to the terminal",
            ["printf", "%s\\n", "two words"],
        )
        self.assertEqual(request["display"], "sudo printf '%s\\n' 'two words'")

    def test_multiline_description_is_kept(self):
        request = floating_sudo.parse_request(
            "sudo true\ntrue > First action > First reason\ntrue > Second action > Second reason\nRisk level: medium > Used to test the format",
            ["true"],
        )
        self.assertEqual(
            request["description"],
            "true > First action > First reason\ntrue > Second action > Second reason",
        )
        self.assertEqual(request["risk_reasoning"], "Used to test the format")

    def test_rejects_bad_requests(self):
        bad_requests = [
            (
                "sudo true\r\ntrue > Test CRLF > Check line endings\r\nRisk level: low > Safe",
                ["true"],
            ),
            ("sudo true\nMissing separators\nRisk level: low > Safe", ["true"]),
            ("sudo true\n > Missing what > Has why\nRisk level: low > Safe", ["true"]),
            ("sudo true\ntrue > Missing why\nRisk level: low > Safe", ["true"]),
            ("sudo true\ntrue > Missing why\nRisk level: low >", ["true"]),
            (
                "sudo true\ntrue > Test risk > Reject bad level\nRisk level: severe > Unknown",
                ["true"],
            ),
            (
                "sudo true\ntrue > Test mismatch > Bind display to argv\nRisk level: low > Safe",
                ["false"],
            ),
            (
                "sudo sudo true\nsudo true > Test leading sudo > Prevent nested sudo\nRisk level: low > Safe",
                ["sudo", "true"],
            ),
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
                    "description": "true > Test the wrapper > Harmless test",
                    "risk": "low",
                    "risk_reasoning": "It changes nothing",
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
        description = (
            "sudo true\ntrue > Test the wrapper > Harmless test\nRisk level: low > It changes nothing"
        )
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(floating_sudo.parent(description, ["true"]), 125)

    def test_cancel_cleans_private_directory(self):
        description = (
            "sudo true\ntrue > Test the wrapper > Harmless test\nRisk level: low > It changes nothing"
        )
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
                ) as process_mock,
            ):
                self.assertEqual(floating_sudo.parent(description, ["true"]), 125)
                kitty_command = process_mock.call_args.args[0]
                self.assertIn("background_opacity=0.3", kitty_command)
            self.assertEqual(list(Path(runtime).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
