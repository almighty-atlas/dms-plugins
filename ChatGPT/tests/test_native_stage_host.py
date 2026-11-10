"""Static contract and syntax checks for a reversible user-owned QS stage."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
STAGE_PATH = ROOT / "stage_private_host.sh"
RUNNER_PATH = ROOT / "run_native_popout.sh"
STAGE = STAGE_PATH.read_text()
RUNNER = RUNNER_PATH.read_text()

class PrivateHostStageTests(unittest.TestCase):
    def test_both_shell_scripts_parse(self):
        for path in (STAGE_PATH, RUNNER_PATH):
            with self.subTest(path=path.name):
                subprocess.run(["bash", "-n", str(path)], check=True)

    def test_source_pinned_and_refuses_implicit_install(self):
        self.assertIn('if [[ "$#" != 1 || "$1" != "--stage" ]]', STAGE)
        self.assertIn("expected_commit=9b0f339b19057f4731bf3b48293307d7ef241671", STAGE)
        self.assertIn("expected_sha256=63e258a5b089565b9a93feca02bce7d5dc6602e719d2c66997356643601290f4", STAGE)
        self.assertIn('source_sha" != "$expected_sha256', STAGE)
        self.assertIn("DMS_PRIVATE_HOST_NO_SERVICE_CHANGE", STAGE)
        self.assertIn("DMS_PRIVATE_HOST_NO_PACKAGE_CHANGE", STAGE)

    def test_private_host_clean_runpath_and_same_file_on_restage(self):
        self.assertIn('base="$HOME/.local/share/dms-chatgpt-native-host"', STAGE)
        self.assertIn('version=9b0f339-argc1-v01', STAGE)
        self.assertIn('patchelf --remove-rpath "$scratch/quickshell"', STAGE)
        self.assertIn('readelf -d "$scratch/quickshell"', STAGE)
        self.assertIn('ldd "$scratch/quickshell"', STAGE)
        self.assertIn('cmp -s "$scratch/quickshell" "$host"', STAGE)
        self.assertIn('cmp -s "$scratch/qs" "$shim"', STAGE)
        self.assertIn('install -m 700 -- "$source_bin"', STAGE)
        self.assertIn('chmod 700 "$base" "$stage" "$stage/host" "$stage/bin"', STAGE)

    def test_staged_host_test_uses_wrapper_offline(self):
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--staged-host-check" ]]', RUNNER)
        self.assertIn('staged_host="$stage_root/host/quickshell"', RUNNER)
        self.assertIn('staged_shim="$stage_root/bin/qs"', RUNNER)
        self.assertIn('binary="$staged_shim"', RUNNER)
        self.assertIn('DMS_NATIVE_STAGED_OFFLINE_ONLY', RUNNER)
        self.assertIn('DMS_SOCKET=""', RUNNER)
        self.assertIn('NIRI_SOCKET=""', RUNNER)
        self.assertIn('dbus-run-session --', RUNNER)

    def test_scripts_never_touch_live_dms_or_pacman_files(self):
        for script in (STAGE, RUNNER):
            for command in (
                "sudo ", "pacman -S", "systemctl --user restart", "systemctl edit",
                "dms restart", "dms plugins install", "pkill", "killall",
                "cp /usr/bin", "mv /usr/bin", "QTWEBENGINE_DISABLE_SANDBOX=1",
            ):
                self.assertNotIn(command, script)
        self.assertNotIn("chmod 700 \"$HOME/.local\" ", STAGE)

if __name__ == "__main__":
    unittest.main()
