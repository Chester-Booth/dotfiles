from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "bin" / "gpu-power-compare"
loader = importlib.machinery.SourceFileLoader("gpu_power_compare", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
gpu_power_compare = importlib.util.module_from_spec(spec)
loader.exec_module(gpu_power_compare)


class GpuPowerCompareTests(unittest.TestCase):
    def test_duration_suffixes(self):
        self.assertEqual(gpu_power_compare.parse_duration("30s"), 30)
        self.assertEqual(gpu_power_compare.parse_duration("5m"), 300)
        self.assertEqual(gpu_power_compare.parse_duration("1h"), 3600)

    def test_report_compares_saved_average_draw(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "hybrid.json").write_text(json.dumps({"averageWatts": 12.5}))
            (path / "integrated.json").write_text(json.dumps({"averageWatts": 10.0}))
            output = io.StringIO()
            with mock.patch.dict(os.environ, {"GPU_POWER_COMPARE_STATE_DIR": directory}):
                with redirect_stdout(output):
                    gpu_power_compare.report()
        self.assertIn("Hybrid:    12.500 W average", output.getvalue())
        self.assertIn("Integrated saved 2.500 W, or 20.0%", output.getvalue())

    def test_measure_refuses_a_wrong_mode_before_reading_the_battery(self):
        with mock.patch.object(gpu_power_compare, "controller_mode", return_value="hybrid"):
            with mock.patch.object(gpu_power_compare, "battery_path") as battery_path:
                with redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        gpu_power_compare.measure("integrated", 1, 1)
        battery_path.assert_not_called()


if __name__ == "__main__":
    unittest.main()
