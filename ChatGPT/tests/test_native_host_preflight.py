"""Safety/source assertions for installed-vs-test Quickshell host audit."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
SCRIPT = (ROOT / "host_preflight.sh").read_text()

class HostPreflightTests(unittest.TestCase):
    def test_only_metadata_default_and_explicit_probe(self):
        self.assertIn("mode=metadata", SCRIPT)
        self.assertIn('if [[ "${1:-}" == "--probe" && "$#" == 1 ]]', SCRIPT)
        self.assertIn("DMS_HOST_NO_RUNTIME_LAUNCHED", SCRIPT)
        self.assertIn("DMS_HOST_PROBE_ONLY_NO_WEBENGINE", SCRIPT)
        self.assertIn("QuickshellArgsProbe.qml", SCRIPT)

    def test_status_no_arguments_or_secrets_printed(self):
        self.assertIn("DMS_QS_ARGC_ZERO", SCRIPT)
        self.assertIn("DMS_QS_ARGC_NONZERO", SCRIPT)
        self.assertIn("ZERO_UNSAFE_FOR_WEBENGINE", SCRIPT)
        self.assertIn("NONZERO_WEBENGINE_PREREQUISITE_MET", SCRIPT)
        self.assertIn("INCONCLUSIVE", SCRIPT)
        self.assertIn("chmod 600", SCRIPT)
        self.assertIn('rm -f -- "$trace"', SCRIPT)
        for forbidden in ("WebEngineView", "QTWEBENGINE_DISABLE_SANDBOX",
                          "journalctl", "cat $trace", "DMS_SOCKET=", "password"):
            self.assertNotIn(forbidden, SCRIPT)

    def test_never_replaces_running_shell(self):
        self.assertIn("timeout --signal=TERM --kill-after=2s 6s", SCRIPT)
        for forbidden in ("sudo ", "pacman -S", "cmake --install", "systemctl",
                          "dms restart", "dms plugins install", "pkill",
                          "killall", "mv /usr/bin", "cp /usr/bin"):
            self.assertNotIn(forbidden, SCRIPT)

if __name__ == "__main__":
    unittest.main()
