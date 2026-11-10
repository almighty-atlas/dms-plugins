"""Structural checks for the experimental isolated argc=1 Quickshell build."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "probes" / "webengine"

class TestIsolatedQuickshellBuild(unittest.TestCase):
    def test_prepare_script_is_strict_and_scoped(self):
        script = (ROOT / "prepare_quickshell.sh").read_text()
        self.assertIn("set -euo pipefail", script)
        self.assertIn("/tmp/dms-chatgpt-qs-v02-argc1", script)
        self.assertIn("9b0f339b19057f4731bf3b48293307d7ef241671", script)
        self.assertIn("s.count(old) == 1", script)
        self.assertIn('git -C "$root/source" diff --check', script)
        self.assertNotIn("pacman -S", script)
        self.assertNotIn("cmake --install", script)
        self.assertNotIn("systemctl", script)

    def test_renderer_has_no_browser_state_or_network(self):
        qml = (ROOT / "QuickshellWebEngineProbe.qml").read_text()
        self.assertIn("import Quickshell", qml)
        self.assertIn("import QtWebEngine", qml)
        self.assertIn("FloatingWindow", qml)
        self.assertIn("loadHtml(", qml)
        self.assertIn("DMS_PATCHED_QS_WEBENGINE_LOADED", qml)
        self.assertNotIn("https://", qml)
        self.assertNotIn("http://", qml)
        self.assertNotIn("WebEngineProfile", qml)
        self.assertNotIn("runJavaScript(", qml)

if __name__ == "__main__":
    unittest.main()
