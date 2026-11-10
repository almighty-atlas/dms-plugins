import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import desktop_smoke


class SmokeTests(unittest.TestCase):
    def test_headless_failure_is_not_reported_as_graphical_pass(self):
        smoke = desktop_smoke.Smoke(False)
        completed = type("Result", (), {"returncode": 0})()
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {
                "WAYLAND_DISPLAY": "", "NIRI_SOCKET": "", "XDG_STATE_HOME": temp}), \
                patch.object(smoke, "run", return_value=completed), contextlib.redirect_stdout(io.StringIO()):
            smoke.desktop(False)
            self.assertEqual(smoke.finish(), 1)
            report = json.loads((Path(temp) / "dms-chatgpt/desktop-smoke.json").read_text())
            self.assertIn({"test": "Wayland + Niri session", "result": "FAIL"}, report["results"])
            self.assertNotIn("Native DMS plugin loaded", str(report))

    def test_noninteractive_visual_checks_are_skipped(self):
        smoke = desktop_smoke.Smoke(False)
        with contextlib.redirect_stdout(io.StringIO()):
            smoke.ask("Visual CSS", "Cannot verify without user")
        self.assertEqual(smoke.results, [{"test": "Visual CSS", "result": "SKIP"}])

    def test_report_only_contains_allowlisted_fields(self):
        smoke = desktop_smoke.Smoke(False)
        smoke.results = [{"test": "Focus", "result": "PASS"}]
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"XDG_STATE_HOME": temp}), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(smoke.finish(), 0)
            path = Path(temp) / "dms-chatgpt/desktop-smoke.json"
            report = json.loads(path.read_text())
            self.assertEqual(set(report), {"results", "versions", "privacy"})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
