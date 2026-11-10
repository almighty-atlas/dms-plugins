"""Offline Screencopy-enabled Quickshell WebEngine DMS popout smoke contracts."""
from pathlib import Path
import subprocess
import unittest

BASE = Path(__file__).resolve().parents[1] / "experiments/native-popout"
RUNNER = BASE / "run_native_popout.sh"
SH = RUNNER.read_text()


class NewHostPopoutTests(unittest.TestCase):
    def test_bash_syntax(self):
        subprocess.run(["bash", "-n", str(RUNNER)], check=True)

    def test_new_mode_is_explicit_and_uses_distinct_binary(self):
        for string in (
            'screencopy_host=0',
            'elif [[ "$#" == 1 && "$1" == "--screencopy-host-check" ]]',
            'screencopy_host=1',
            'if [[ "$screencopy_host" == 1 ]]',
            'screencopy_build=/tmp/dms-chatgpt-qs-v02-argc1/build-dms-screencopy-v01',
            'binary="$screencopy_build/src/quickshell"',
            'DMS_NATIVE_SCREENCOPY_HOST_OFFLINE_ONLY',
            'DMS_NATIVE_SCREENCOPY_HOST_NO_SERVICE_CHANGE',
        ):
            self.assertIn(string, SH)

    def test_pinned_screencopy_host_safety_checks(self):
        for string in (
            "SCREENCOPY_ICC", "SCREENCOPY_WLR", "SCREENCOPY_HYPRLAND_TOPLEVEL",
            'ldd "$binary"', 'cd -- "$screencopy_build"',
            '! -O "$binary"', "DMS_NATIVE_SCREENCOPY_HOST_BLOCKED",
        ):
            self.assertIn(string, SH)

    def test_original_modes_and_offline_sandbox_remain(self):
        for string in (
            '--auth-chatgpt', '--staged-host-check', '--public-chatgpt',
            'binary=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell',
            'online=0', 'auth=0', 'persistent=0',
            'DMS_NATIVE_ONLINE_PROBE="$online"', 'DMS_NATIVE_AUTH_PROBE="$auth"',
            'DMS_SOCKET=""', 'NIRI_SOCKET=""',
            'dbus-run-session --',
            'timeout --signal=TERM --kill-after=3s "$duration"',
        ):
            self.assertIn(string, SH)

    def test_no_production_host_mutations(self):
        for forbidden in (
            'sudo ', 'pacman -S', 'systemctl ', 'dms restart',
            'dms plugins install', 'cmake --install',
            'QTWEBENGINE_DISABLE_SANDBOX=1', '--no-sandbox',
        ):
            self.assertNotIn(forbidden, SH)


if __name__ == "__main__":
    unittest.main()
