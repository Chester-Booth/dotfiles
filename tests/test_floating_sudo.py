from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import base64
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import stat
import tempfile
import threading
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
        self.assertIn("approved", help_text)

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
        self.relay_path = self.request_path.with_name(floating_sudo.RELAY_SOCKET_NAME)
        self.relay_server = floating_sudo.create_relay_server(self.relay_path)
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
        self.relay_server.close()
        self.relay_path.unlink(missing_ok=True)
        self.directory.cleanup()

    def read_events(self):
        self.relay_server.settimeout(1)
        connection, _ = self.relay_server.accept()
        reader = floating_sudo.RelayReader()
        events = []
        with connection:
            while True:
                data = connection.recv(4096)
                if not data:
                    break
                events.extend(reader.feed(data))
        return events

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="")
    def test_default_rejects_without_sudo(self, _input, _notify):
        with mock.patch.object(floating_sudo.subprocess, "run") as run:
            self.assertEqual(floating_sudo.child(self.request_path), 125)
            run.assert_not_called()

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="Y")
    def test_approval_relays_exit_status(self, _input, _notify):
        with mock.patch.object(floating_sudo, "run_privileged", return_value=7):
            self.assertEqual(floating_sudo.child(self.request_path), 7)
        self.assertEqual(
            [event["event"] for event in self.read_events()],
            ["awaiting_approval", "approved", "running", "finished"],
        )

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="y")
    def test_signal_uses_shell_exit_convention(self, _input, _notify):
        with mock.patch.object(
            floating_sudo, "run_privileged", return_value=143
        ):
            self.assertEqual(floating_sudo.child(self.request_path), 143)
        self.read_events()

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value=" y ")
    def test_approval_ignores_outer_space(self, _input, _notify):
        with mock.patch.object(
            floating_sudo, "run_privileged", return_value=0
        ):
            self.assertEqual(floating_sudo.child(self.request_path), 0)
        self.read_events()

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="")
    def test_rejection_is_relayed_without_running(self, _input, _notify):
        self.assertEqual(floating_sudo.child(self.request_path), 125)
        self.assertEqual(
            [event["event"] for event in self.read_events()],
            ["awaiting_approval", "finished"],
        )

    def test_missing_relay_fails_closed(self):
        self.relay_server.close()
        self.relay_path.unlink()
        with mock.patch.object(floating_sudo, "run_privileged") as run:
            self.assertEqual(floating_sudo.child(self.request_path), 125)
        run.assert_not_called()
        self.assertEqual(
            json.loads((self.request_path.parent / "result.json").read_text())["code"],
            125,
        )

    def test_event_frames_survive_partial_reads(self):
        frame = floating_sudo.encode_event(
            floating_sudo.output_event("stdout", b"output\x00")
        )
        reader = floating_sudo.RelayReader()
        self.assertEqual(reader.feed(frame[:2]), [])
        self.assertEqual(reader.feed(frame[2:7]), [])
        events = reader.feed(frame[7:])
        self.assertEqual(
            base64.b64decode(events[0]["data"], validate=True), b"output\x00"
        )

    def test_mixed_stream_events_keep_stream_identity(self):
        frames = b"".join(
            (
                floating_sudo.encode_event(
                    floating_sudo.output_event("stdout", b"out")
                ),
                floating_sudo.encode_event(
                    floating_sudo.output_event("stderr", b"err")
                ),
            )
        )
        reader = floating_sudo.RelayReader()
        self.assertEqual(
            [event["event"] for event in reader.feed(frames)], ["stdout", "stderr"]
        )

    @mock.patch.object(floating_sudo, "SUDO", Path("/usr/bin/env"))
    def test_command_output_is_teed_to_the_relay(self):
        sender_socket, receiver_socket = socket.socketpair()
        relay = floating_sudo.RelaySender(sender_socket)
        output = io.StringIO()
        with redirect_stdout(output), redirect_stderr(io.StringIO()):
            self.assertEqual(
                floating_sudo.run_privileged(
                    [
                        "python3",
                        "-c",
                        "import sys; sys.stdout.buffer.write(b'out\\x00'); sys.stderr.buffer.write(b'err\\x00')",
                    ],
                    relay,
                ),
                0,
            )
        relay.close()
        reader = floating_sudo.RelayReader()
        events = []
        with receiver_socket:
            while True:
                data = receiver_socket.recv(4096)
                if not data:
                    break
                events.extend(reader.feed(data))
        self.assertEqual(
            {
                event["event"]: base64.b64decode(event["data"], validate=True)
                for event in events
            },
            {"stdout": b"out\x00", "stderr": b"err\x00"},
        )
        self.assertIn("out\x00", output.getvalue())

    @mock.patch.object(floating_sudo, "notify")
    @mock.patch("builtins.input", return_value="")
    def test_three_request_sections_and_description_format_are_highlighted(
        self, _input, _notify
    ):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(floating_sudo.child(self.request_path), 125)
        text = output.getvalue()
        for section in ("Command", "Description", "Risk"):
            self.assertIn(f"{floating_sudo.BOLD}{floating_sudo.CYAN}{section}", text)
        self.assertIn(
            f"{floating_sudo.BOLD}{floating_sudo.CYAN}command > what > why",
            text,
        )
        self.read_events()

    def test_result_is_private_and_atomic(self):
        result = Path(self.directory.name) / "result.json"
        floating_sudo.atomic_json(result, {"code": 0})
        self.assertEqual(stat.S_IMODE(result.stat().st_mode), 0o600)
        self.assertEqual(json.loads(result.read_text()), {"code": 0})
        self.assertEqual(list(result.parent.glob(".*.tmp")), [])


class ParentTests(unittest.TestCase):
    class FakeProcess:
        def __init__(self):
            self.returncode = None
            self.done = threading.Event()
            self.terminated = False

        def poll(self):
            return self.returncode

        def wait(self, timeout=None):
            self.done.wait(timeout)
            return self.returncode

        def terminate(self):
            self.terminated = True
            self.returncode = 125
            self.done.set()

        def kill(self):
            self.terminate()

    def relay_process(self, runtime, events, result, process):
        server = floating_sudo.create_relay_server(runtime / "relay.sock")

        def send_events():
            connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            connection.connect(str(runtime / "relay.sock"))
            with connection:
                for event in events:
                    connection.sendall(floating_sudo.encode_event(event))
                if result is not None:
                    floating_sudo.atomic_json(runtime / "result.json", result)
            process.returncode = result["code"] if result is not None else 9
            process.done.set()

        thread = threading.Thread(target=send_events)
        thread.start()
        try:
            state = {"approved": False, "started": False}
            return floating_sudo.relay_parent(
                server, process, runtime / "result.json", state
            )
        finally:
            thread.join(timeout=2)
            server.close()
            (runtime / "relay.sock").unlink(missing_ok=True)

    def test_missing_gui_fails_closed(self):
        description = (
            "sudo true\ntrue > Test the wrapper > Harmless test\nRisk level: low > It changes nothing"
        )
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(floating_sudo.parent(description, ["true"]), 125)

    def test_parent_relays_live_output_and_uses_final_result(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            process = self.FakeProcess()
            events = [
                floating_sudo.make_event("awaiting_approval"),
                floating_sudo.make_event("approved"),
                floating_sudo.make_event("running"),
                floating_sudo.output_event("stdout", b"out\x00"),
                floating_sudo.output_event("stderr", b"err\x00"),
                floating_sudo.make_event("finished", outcome="completed", code=7),
            ]
            output = io.StringIO()
            error = io.StringIO()
            with redirect_stdout(output), redirect_stderr(error):
                self.assertEqual(
                    self.relay_process(
                        runtime,
                        events,
                        {"outcome": "completed", "code": 7},
                        process,
                    ),
                    7,
                )
            self.assertEqual(output.getvalue(), "out\x00")
            self.assertEqual(
                error.getvalue(),
                "\033[1m\033[92mApproved. Running sudo now.\033[0m\nerr\x00",
            )

    def test_relay_loss_before_approval_stops_the_window(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            process = self.FakeProcess()
            self.assertEqual(
                self.relay_process(
                    runtime,
                    [floating_sudo.make_event("awaiting_approval")],
                    None,
                    process,
                ),
                125,
            )

    def test_relay_loss_after_start_waits_for_the_command(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            process = self.FakeProcess()
            self.assertEqual(
                self.relay_process(
                    runtime,
                    [
                        floating_sudo.make_event("awaiting_approval"),
                        floating_sudo.make_event("approved"),
                        floating_sudo.make_event("running"),
                    ],
                    None,
                    process,
                ),
                9,
            )
            self.assertFalse(process.terminated)

    def test_cleanup_removes_request_with_a_dead_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            stale = runtime / "floating-sudo-stale"
            stale.mkdir(mode=0o700)
            os.chmod(stale, 0o700)
            floating_sudo.write_private_text(
                stale / floating_sudo.OWNER_FILE_NAME, "999999999\n"
            )
            with mock.patch.object(floating_sudo, "pid_is_alive", return_value=False):
                floating_sudo.cleanup_stale_requests(runtime)
            self.assertFalse(stale.exists())

    def test_conflicting_package_request_returns_75(self):
        description = (
            "sudo pacman -S jq\npacman -S jq > Install jq > Add the JSON processor\n"
            "Risk level: low > It comes from the configured package source"
        )
        with tempfile.TemporaryDirectory() as runtime:
            lock = floating_sudo.acquire_lock(
                Path(runtime) / floating_sudo.PACKAGE_LOCK_NAME
            )
            try:
                environment = {
                    "XDG_RUNTIME_DIR": runtime,
                    "WAYLAND_DISPLAY": "wayland-1",
                }
                with (
                    mock.patch.dict(os.environ, environment, clear=True),
                    mock.patch.object(
                        Path,
                        "is_file",
                        autospec=True,
                        side_effect=lambda path: path
                        in (floating_sudo.KITTY, floating_sudo.SUDO),
                    ),
                ):
                    self.assertEqual(
                        floating_sudo.parent(description, ["pacman", "-S", "jq"]),
                        floating_sudo.REQUEST_BUSY,
                    )
            finally:
                floating_sudo.release_lock(lock)

    def test_cancel_cleans_private_directory(self):
        description = (
            "sudo true\ntrue > Test the wrapper > Harmless test\nRisk level: low > It changes nothing"
        )
        with tempfile.TemporaryDirectory() as runtime:
            environment = {"XDG_RUNTIME_DIR": runtime, "WAYLAND_DISPLAY": "wayland-1"}
            process = mock.Mock()
            process.wait.return_value = 125
            process.poll.return_value = 125
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
