import importlib.util
import json
import unittest
from pathlib import Path
from unittest import mock


MODULE = Path(__file__).parents[1] / "quickshell/.config/quickshell/blox/scripts/launcher/appctl.py"
SPEC = importlib.util.spec_from_file_location("appctl", MODULE)
appctl = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(appctl)


class AppControllerTests(unittest.TestCase):
    def test_normalise_ignores_case_and_desktop_suffix(self):
        self.assertEqual("org.example.app", appctl.normalise("Org.Example.App.desktop"))

    @mock.patch.object(appctl.subprocess, "run")
    @mock.patch.object(appctl.subprocess, "check_output")
    def test_focuses_the_most_recent_matching_window(self, check_output, run):
        check_output.return_value = json.dumps([
            {"address": "0xold", "class": "Example", "initialClass": "", "focusHistoryID": 8},
            {"address": "0xnew", "class": "other", "initialClass": "example.desktop", "focusHistoryID": 0},
        ]).encode()
        run.return_value.returncode = 0
        with mock.patch.object(appctl.sys, "argv", ["appctl.py", "Example.desktop"]):
            self.assertEqual(0, appctl.main())
        self.assertEqual("address:0xnew", run.call_args.args[0][-1])

    @mock.patch.object(appctl.subprocess, "check_output", return_value=b"[]")
    def test_returns_three_when_the_app_is_not_running(self, _check_output):
        with mock.patch.object(appctl.sys, "argv", ["appctl.py", "missing"]):
            self.assertEqual(3, appctl.main())


if __name__ == "__main__":
    unittest.main()
