"""Conservative source and syntax tests for the isolated ShellCore QML gate."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
PROBE_PATH = ROOT / "verify_dms_shellcore_type_tree.sh"
FIXTURE_PATH = ROOT / "DmsShellCoreLoadProbe.qml"
PROBE = PROBE_PATH.read_text()
FIXTURE = FIXTURE_PATH.read_text()


class ShellCoreTypeTreeTests(unittest.TestCase):
    def test_shell_script_parses(self):
        subprocess.run(["bash", "-n", str(PROBE_PATH)], check=True)

    def test_real_dms_source_and_new_build_are_pinned(self):
        self.assertIn('build-dms-screencopy-v01', PROBE)
        self.assertIn("dms_pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42", PROBE)
        self.assertIn("common_pin=0877466a25b8e191a865bf75d0e500de6351ae04", PROBE)
        self.assertIn('git -C "$dms_source" rev-parse HEAD', PROBE)
        self.assertIn('git -C "$dcommon" rev-parse HEAD', PROBE)
        self.assertIn('SCREENCOPY:BOOL=(ON|TRUE)', PROBE)

    def test_shellcore_loaded_not_instantiated(self):
        self.assertIn('Qt.createComponent(', FIXTURE)
        self.assertIn('Qt.resolvedUrl("ShellCore.qml")', FIXTURE)
        self.assertIn('Component.PreferSynchronous', FIXTURE)
        self.assertIn('component.status === Component.Ready', FIXTURE)
        self.assertIn("DMS_SHELLCORE_QML_TYPE_TREE_READY", FIXTURE)
        self.assertNotIn('component.createObject(', FIXTURE)
        self.assertNotIn('shell.qml', FIXTURE)
        self.assertIn('DMS_SHELLCORE_ONLY_COMPILED_NOT_INSTANTIATED', PROBE)

    def test_sandbox_not_connected_to_running_dms_or_niri(self):
        self.assertIn('dbus-run-session --', PROBE)
        self.assertIn('DMS_SOCKET="" NIRI_SOCKET=""', PROBE)
        self.assertIn('GSETTINGS_BACKEND="memory"', PROBE)
        self.assertIn('timeout --signal=TERM --kill-after=2s 12s', PROBE)
        self.assertIn('"$binary" --path "$fixture"', PROBE)
        self.assertIn('DMS_SHELLCORE_ISOLATED_XDG_AND_DBUS', PROBE)
        self.assertIn('DMS_SHELLCORE_NO_LIVE_DMS_CHANGES', PROBE)

    def test_unique_ephemeral_qml_and_cleanup(self):
        self.assertIn('mktemp "$qml_root/DmsShellCoreLoadProbe_XXXXXXXX.qml"', PROBE)
        self.assertIn('cp -- "$source_fixture" "$fixture"', PROBE)
        self.assertIn('trap cleanup EXIT', PROBE)
        self.assertIn('rm -f -- "$fixture"', PROBE)
        self.assertIn('rm -rf -- "$private"', PROBE)
        self.assertIn('! grep -Fq "DMS_SHELLCORE_QML_TYPE_TREE_READY"', PROBE)
        self.assertIn('DMS_SHELLCORE_QML_TYPE_TREE_FAILED', PROBE)
        for forbidden in (
            "sudo ", "pacman -S", "systemctl --user restart",
            "systemctl --user daemon-reload", "dms restart", "dms plugins install",
            "pkill", "killall", "WebEngineView", "chatgpt.com",
        ):
            self.assertNotIn(forbidden, PROBE)


if __name__ == "__main__":
    unittest.main()
