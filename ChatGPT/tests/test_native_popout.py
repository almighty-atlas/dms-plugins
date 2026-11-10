"""Source-only safety contracts for the isolated experimental DMS native popout."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments" / "native-popout"

class NativeCandidateContracts(unittest.TestCase):
    def test_only_source_experiment_no_manifest(self):
        self.assertFalse((ROOT / "plugin.json").exists())
        widget = (ROOT / "Widget.qml").read_text()
        self.assertIn("PluginComponent {", widget)
        self.assertIn("popoutContent: Component", widget)
        self.assertIn("PopoutComponent {", widget)
        self.assertNotRegex(widget, r"(?m)^\s*pillClickAction\s*:")
        self.assertIn("function triggerHoverPopout() {}", widget)
        self.assertIn("WebEngineView {", widget)

    def test_offline_and_profile_parent_scope(self):
        widget = (ROOT / "Widget.qml").read_text()
        self.assertIn("WebEngineProfilePrototype {", widget)
        self.assertIn("profileFactory.instance()", widget)
        self.assertLess(widget.index("WebEngineProfilePrototype {"),
                        widget.index("popoutContent: Component"))
        self.assertIn("profile: root.webProfile", widget)
        self.assertIn("persistentCookiesPolicy: WebEngineProfile.OnlyPersistentCookies", widget)
        self.assertIn("persistentPermissionsPolicy: WebEngineProfile.AskEveryTime", widget)
        self.assertIn("permission.deny()", widget)
        self.assertNotIn("https://", widget)
        self.assertNotIn("http://", widget)
        self.assertNotIn("WebChannel", widget)
        self.assertNotIn("runJavaScript(", widget)

    def test_test_harness_is_separate(self):
        shell = (ROOT / "ChatGPTNativeHarness.qml").read_text()
        self.assertIn("ShellRoot {", shell)
        self.assertIn("Native.Widget {", shell)
        self.assertNotIn("DMSShell", shell)
        self.assertNotIn("SystemTray", shell)
        self.assertNotIn("Exec", shell)

    def test_prep_doesnt_install_or_start(self):
        sh = (ROOT / "prepare_sandbox.sh").read_text()
        self.assertIn("set -euo pipefail", sh)
        self.assertIn("e46ccbc1d58930d6a189cd1c90b276db2d64bf42", sh)
        self.assertIn('git -C "$source_dir" fetch -q --depth 1 origin "$pin"', sh)
        self.assertIn("/tmp/dms-chatgpt-native-v02", sh)
        for forbidden in ("pacman -S", "cmake --install", "systemctl",
                          "dms restart", "dms plugins install"):
            self.assertNotIn(forbidden, sh)

if __name__ == "__main__":
    unittest.main()
