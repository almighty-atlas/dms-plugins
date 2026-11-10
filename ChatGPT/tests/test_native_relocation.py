"""Contracts for private, offline relocation of the patched Quickshell host."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
RUNNER = (ROOT / "run_native_popout.sh").read_text()

class NativeRelocationTests(unittest.TestCase):
    def test_mode_explicit_and_offline_only(self):
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--relocation-check" ]]', RUNNER)
        self.assertIn("online=0", RUNNER)
        self.assertIn("persistent=0", RUNNER)
        self.assertIn("auth=0", RUNNER)
        self.assertIn("relocation=1", RUNNER)
        self.assertIn("DMS_NATIVE_RELOCATION_TEST: actual DMS PluginPopout, offline only", RUNNER)
        self.assertIn('DMS_NATIVE_AUTH_PROBE="$auth"', RUNNER)

    def test_only_copies_to_private_test_path_with_matching_hash(self):
        self.assertIn('portable_dir="$root/portable-host"', RUNNER)
        self.assertIn('portable_bin="$portable_dir/quickshell"', RUNNER)
        self.assertIn('install -m 700 "$binary" "$portable_bin"', RUNNER)
        self.assertIn('sha256sum "$binary"', RUNNER)
        self.assertIn('sha256sum "$portable_bin"', RUNNER)
        self.assertIn('original_hash" != "$portable_hash', RUNNER)
        self.assertIn('binary="$portable_bin"', RUNNER)
        self.assertIn('ldd "$portable_bin"', RUNNER)

    def test_relocated_host_uses_same_isolated_dms_harness(self):
        self.assertIn('harness="$qml_root/ChatGPTNativeHarness.qml"', RUNNER)
        self.assertIn('"$binary" --path "$harness"', RUNNER)
        self.assertIn('DMS_SOCKET=""', RUNNER)
        self.assertIn('NIRI_SOCKET=""', RUNNER)
        self.assertIn('dbus-run-session --', RUNNER)
        self.assertIn('timeout --signal=TERM --kill-after=3s "$duration"', RUNNER)
        self.assertIn('duration=60s', RUNNER)
        for forbidden in ("cmake --install", "pacman -S", "sudo ", "systemctl ",
                          "dms restart", "pkill", "killall", "--no-sandbox"):
            self.assertNotIn(forbidden, RUNNER)

if __name__ == "__main__":
    unittest.main()
