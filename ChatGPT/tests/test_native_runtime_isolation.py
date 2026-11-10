"""Source-level contracts for a bounded, isolated DMS popup runtime test."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
SCRIPT = (ROOT / "run_native_popout.sh").read_text()

class NativeRuntimeIsolationTests(unittest.TestCase):
    def test_pinned_private_host_and_source(self):
        self.assertIn("set -euo pipefail", SCRIPT)
        self.assertIn("umask 077", SCRIPT)
        self.assertIn("/tmp/dms-chatgpt-native-v02", SCRIPT)
        self.assertIn("/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell", SCRIPT)
        self.assertIn("e46ccbc1d58930d6a189cd1c90b276db2d64bf42", SCRIPT)
        self.assertIn("9b0f339b19057f4731bf3b48293307d7ef241671", SCRIPT)

    def test_private_ipc_and_state(self):
        self.assertIn("/usr/bin/env -i", SCRIPT)
        self.assertIn("dbus-run-session --", SCRIPT)
        self.assertIn('DMS_SOCKET=""', SCRIPT)
        self.assertIn('NIRI_SOCKET=""', SCRIPT)
        self.assertIn('GSETTINGS_BACKEND="memory"', SCRIPT)
        self.assertIn('XDG_RUNTIME_DIR="$root/runtime"', SCRIPT)
        self.assertIn('XDG_CONFIG_HOME="$root/config"', SCRIPT)
        self.assertIn('XDG_DATA_HOME="$root/data"', SCRIPT)
        self.assertIn('XDG_CACHE_HOME="$root/cache"', SCRIPT)
        self.assertIn('XDG_STATE_HOME="$root/state"', SCRIPT)
        self.assertIn('HOME="$root/home"', SCRIPT)
        self.assertIn('WAYLAND_DISPLAY="$socket"', SCRIPT)

    def test_sandbox_flags_and_deadline(self):
        self.assertIn("QTWEBENGINE_DISABLE_SANDBOX", SCRIPT)
        self.assertIn("QTWEBENGINE_CHROMIUM_FLAGS", SCRIPT)
        self.assertIn('[[ -S "$socket" ]]', SCRIPT)
        self.assertIn("timeout --signal=TERM --kill-after=3s 60s", SCRIPT)
        for forbidden in ("sudo ", "pacman -S", "cmake --install",
                          "dms restart", "dms plugins install", "systemctl ", "--no-sandbox"):
            self.assertNotIn(forbidden, SCRIPT)

    def test_explicit_offline_only(self):
        widget = (ROOT / "Widget.qml").read_text()
        self.assertIn("loadHtml(", widget)
        self.assertNotIn("https://", widget)
        self.assertNotIn("http://", widget)

if __name__ == "__main__":
    unittest.main()
