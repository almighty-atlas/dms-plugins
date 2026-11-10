"""Safe, separate, versioned stage for the full DMS Screencopy host."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
STAGER = ROOT / "stage_private_screencopy_host.sh"
RUNNER = ROOT / "run_native_popout.sh"
S = STAGER.read_text()
R = RUNNER.read_text()


class ScreencopyPrivateStageTests(unittest.TestCase):
    def test_shell_syntax(self):
        for script in (STAGER, RUNNER):
            with self.subTest(path=script.name):
                subprocess.run(["bash", "-n", str(script)], check=True)

    def test_new_stage_is_distinct_pinned_and_non_overwriting(self):
        self.assertIn("version=9b0f339-argc1-screencopy-v02", S)
        self.assertIn("pin=9b0f339b19057f4731bf3b48293307d7ef241671", S)
        self.assertIn('build_dir="$root/build-dms-screencopy-v01"', S)
        self.assertIn('source_bin="$build_dir/src/quickshell"', S)
        self.assertIn('if [[ -e "$stage" || -L "$stage" ||', S)
        self.assertIn('mv -T -- "$scratch" "$stage"', S)
        self.assertIn("DMS_SCREENCOPY_PRIVATE_OLD_VERSION_UNCHANGED", S)
        self.assertNotIn("version=9b0f339-argc1-v01", S)

    def test_source_and_full_critical_module_validation(self):
        self.assertIn('git -C "$source_dir" status --porcelain', S)
        self.assertIn('original.replace(before, after)', S)
        for flag in ("WAYLAND", "WAYLAND_WLR_LAYERSHELL",
                     "SCREENCOPY", "SCREENCOPY_ICC", "SCREENCOPY_WLR",
                     "SCREENCOPY_HYPRLAND_TOPLEVEL"):
            self.assertIn(flag, S)
        self.assertIn('CMakeCache.txt', S)
        self.assertIn('git -C "$source_dir" diff --check', S)

    def test_relocated_binary_integrity(self):
        self.assertIn('patchelf --remove-rpath "$scratch/host/quickshell"', S)
        self.assertIn('readelf -d "$scratch/host/quickshell"', S)
        self.assertIn('ldd "$scratch/host/quickshell"', S)
        self.assertIn('"$scratch/host.sha256"', S)
        self.assertIn('actual=$(sha256sum "$host"', S)
        self.assertIn('"$actual" != "$recorded"', S)
        self.assertIn('DMS_SCREENCOPY_PRIVATE_HOST_VERIFIED: YES', S)

    def test_runner_only_opt_in_and_offline(self):
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--screencopy-staged-host-check" ]]', R)
        self.assertIn('screencopy_staged_host=1', R)
        self.assertIn('new_stage="$HOME/.local/share/dms-chatgpt-native-host/9b0f339-argc1-screencopy-v02"', R)
        self.assertIn('bash "$stage_script" --verify', R)
        self.assertIn('binary="$new_stage/bin/qs"', R)
        self.assertIn('DMS_NATIVE_SCREENCOPY_STAGED_OFFLINE_ONLY', R)
        self.assertIn('online=0', R)
        self.assertIn('auth=0', R)
        self.assertIn('DMS_SOCKET=""', R)
        self.assertIn('NIRI_SOCKET=""', R)
        self.assertIn('dbus-run-session --', R)
        self.assertIn('timeout --signal=TERM --kill-after=3s "$duration"', R)
        self.assertIn('binary=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell', R)

    def test_stager_does_not_touch_production(self):
        for script in (S, R):
            for forbidden in ('sudo ', 'pacman -S', 'systemctl ',
                              'dms restart', 'dms plugins install',
                              'cmake --install', 'pkill', 'killall',
                              'QTWEBENGINE_DISABLE_SANDBOX=1'):
                self.assertNotIn(forbidden, script)
        self.assertIn('DMS_SCREENCOPY_PRIVATE_NO_PRODUCTION_ACTIVATION', S)
        self.assertIn('DMS_SCREENCOPY_PRIVATE_NO_SERVICE_CHANGE', S)


if __name__ == "__main__":
    unittest.main()
