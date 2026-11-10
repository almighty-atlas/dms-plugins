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

    def test_layershell_build_is_pinned_and_isolated(self):
        script = (ROOT / "prepare_quickshell_layershell.sh").read_text()
        self.assertIn("set -euo pipefail", script)
        self.assertIn("/tmp/dms-chatgpt-qs-v02-argc1", script)
        self.assertIn("9b0f339b19057f4731bf3b48293307d7ef241671", script)
        self.assertIn("-DWAYLAND=ON", script)
        self.assertIn("-DWAYLAND_WLR_LAYERSHELL=ON", script)
        self.assertIn('grep -Fq \'auto qArgC = 1;\'', script)
        self.assertNotIn("cmake --install", script)
        self.assertNotIn("pacman -S", script)
        self.assertNotIn("systemctl", script)

    def test_layershell_probe_is_offline_and_interactive(self):
        qml = (ROOT / "QuickshellLayerShellProbe.qml").read_text()
        self.assertIn("PanelWindow", qml)
        self.assertIn("WlrLayershell.keyboardFocus", qml)
        self.assertIn("WlrKeyboardFocus.OnDemand", qml)
        self.assertIn("WebEngineView", qml)
        self.assertIn("type='text'", qml)
        self.assertIn("DMS_LAYERSHELL_WEBENGINE_LOADED", qml)
        self.assertNotIn("https://", qml)
        self.assertNotIn("http://", qml)
        self.assertNotIn("runJavaScript(", qml)

    def test_online_probe_is_ephemeral_and_explicit(self):
        qml = (ROOT / "QuickshellChatGPTPageProbe.qml").read_text()
        self.assertIn("import Quickshell", qml)
        self.assertIn("import QtWebEngine", qml)
        self.assertIn("FloatingWindow", qml)
        self.assertIn('url: "https://chatgpt.com/"', qml)
        self.assertIn("offTheRecord: true", qml)
        self.assertIn("profile: temporaryProfile", qml)
        self.assertIn("do not sign in", qml)
        self.assertIn("DMS_PATCHED_QS_CHATGPT_PAGE_LOAD_SUCCEEDED", qml)
        self.assertNotIn("persistentStoragePath", qml)
        self.assertNotIn("runJavaScript(", qml)
        self.assertNotIn("WebChannel", qml)

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
