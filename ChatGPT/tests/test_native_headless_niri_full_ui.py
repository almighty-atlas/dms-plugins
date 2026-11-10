"""Safety contracts for isolated, headless Niri DMS frontend runtime trial."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
OUTER = ROOT / "run_dms_headless_niri.sh"
INNER = ROOT / "run_dms_headless_niri_inner.sh"
O = OUTER.read_text()
I = INNER.read_text()


class HeadlessNiriFullUiTests(unittest.TestCase):
    def test_both_scripts_parse(self):
        for path in (OUTER, INNER):
            with self.subTest(script=path.name):
                subprocess.run(["bash", "-n", str(path)], check=True)

    def test_only_explicit_opt_in_and_separate_host(self):
        self.assertIn('if [[ "$#" != 1 || "$1" != "--headless-probe" ]]', O)
        self.assertIn('build-dms-screencopy-v01', O)
        self.assertIn('dms_pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42', O)
        self.assertIn('common_pin=0877466a25b8e191a865bf75d0e500de6351ae04', O)
        self.assertIn('SCREENCOPY_WLR', O)
        self.assertIn('WAYLAND_WLR_LAYERSHELL', O)
        self.assertIn('git -C "$dms_source" diff --quiet', O)

    def test_niri_never_imports_real_session(self):
        self.assertIn('NIRI_BACKEND="headless"', O)
        self.assertIn('niri --config "$private/config/niri.kdl"', I)
        self.assertIn('DMS_SOCKET="" NOTIFY_SOCKET=""', O)
        self.assertIn('WAYLAND_DISPLAY="" NIRI_SOCKET=""', O)
        self.assertIn('DBUS_SYSTEM_BUS_ADDRESS="unix:path=$private/runtime/no-system-bus"', O)
        self.assertIn('dbus-run-session --', O)
        self.assertIn('XDG_RUNTIME_DIR="$private/runtime"', O)
        self.assertIn('NIRI_BACKEND:-', I)
        self.assertIn('DMS_HEADLESS_NIRI_NO_SESSION_IMPORT', I)
        # Empty values are intentional: Bash's :- fallback would reject them.
        for key in ("DMS_SOCKET", "NOTIFY_SOCKET", "NIRI_SOCKET"):
            self.assertIn("${" + key + "-something}", I)
            self.assertNotIn("${" + key + ":-something}", I)
        self.assertNotIn('niri --session', I)
        self.assertNotIn('niri-session', I)

    def test_real_shell_source_instrumented_only_in_disposable_file(self):
        self.assertIn('mktemp "$qml_root/DmsHeadlessShell_XXXXXXXX.qml"', O)
        self.assertIn('source.replace(a, b).replace(c, d)', O)
        self.assertIn('DMS_HEADLESS_ENTRY_INSTANTIATED', O)
        self.assertIn('DMS_HEADLESS_DMSSHELL_LOADED', O)
        self.assertIn('rm -f -- "$fixture"', O)
        self.assertIn('rm -rf -- "$private"', O)
        self.assertIn('trap cleanup EXIT', O)

    def test_bounded_child_shutdown_and_runtime_markers(self):
        self.assertIn('timeout --signal=TERM --kill-after=5s 38s', O)
        self.assertIn('timeout --signal=TERM --kill-after=3s 16s', I)
        self.assertIn('trap cleanup_inner EXIT', I)
        self.assertIn('kill -TERM "$niri_pid"', I)
        self.assertIn('DMS_HEADLESS_BACKEND_READY: NOT_TESTED', I)
        self.assertIn('DMS_HEADLESS_NO_LIVE_NIRI_OR_DMS_CHANGES', I)
        self.assertIn('DMS_HEADLESS_FULL_UI_FAILED', I)
        self.assertIn('ScreencopyView is not a type', I)

    def test_does_not_modify_live_system_or_read_auth_profile(self):
        for script in (O, I):
            for forbidden in (
                'sudo ', 'pacman -S', 'systemctl --user restart',
                'systemctl --user daemon-reload', 'dms restart',
                'dms plugins install', 'cmake --install',
                'auth-probe', 'chatgpt.com', 'QTWEBENGINE_DISABLE_SANDBOX=1',
                'niri --session', 'niri-session',
            ):
                self.assertNotIn(forbidden, script)


if __name__ == "__main__":
    unittest.main()
