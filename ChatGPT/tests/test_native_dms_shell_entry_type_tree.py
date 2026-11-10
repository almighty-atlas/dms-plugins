"""Contract test for isolated top-level DMS shell.qml type loading."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
RUNNER = ROOT / "verify_dms_shellcore_type_tree.sh"
FIXTURE = ROOT / "DmsShellEntrypointLoadProbe.qml"
SH = RUNNER.read_text()
QML = FIXTURE.read_text()


class ShellEntryTypeTreeTests(unittest.TestCase):
    def test_runner_syntax(self):
        subprocess.run(["bash", "-n", str(RUNNER)], check=True)

    def test_entrypoint_is_loaded_not_created(self):
        self.assertIn('Qt.createComponent(', QML)
        self.assertIn('Qt.resolvedUrl("shell.qml")', QML)
        self.assertIn('Component.PreferSynchronous', QML)
        self.assertIn('component.status === Component.Ready', QML)
        self.assertNotIn('component.createObject(', QML)
        self.assertIn("DMS_SHELL_ENTRY_QML_TYPE_TREE_READY", QML)
        self.assertIn("DMS_SHELL_ENTRY_QML_TYPE_TREE_FAILED", QML)

    def test_entry_probe_uses_pinned_private_dms_and_new_host(self):
        self.assertIn('DmsShellEntrypointLoadProbe.qml', SH)
        self.assertIn('if [[ "$mode" == "--entry-probe" ]]', SH)
        self.assertIn('build-dms-screencopy-v01', SH)
        self.assertIn('! -f "$qml_root/shell.qml"', SH)
        self.assertIn('dms_pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42', SH)
        self.assertIn('common_pin=0877466a25b8e191a865bf75d0e500de6351ae04', SH)
        self.assertIn('expected_ready=DMS_SHELL_ENTRY_QML_TYPE_TREE_READY', SH)
        self.assertIn('echo "DMS_SHELL_ENTRY_QML_TYPE_TREE_READY: YES"', SH)

    def test_runtime_only_checks_types_and_is_isolated(self):
        for required in ('dbus-run-session --', 'DMS_SOCKET="" NIRI_SOCKET=""',
                         'GSETTINGS_BACKEND="memory"',
                         'timeout --signal=TERM --kill-after=2s 12s',
                         'DMS_SHELLCORE_ONLY_COMPILED_NOT_INSTANTIATED',
                         'DMS_SHELLCORE_NO_LIVE_DMS_CHANGES'):
            self.assertIn(required, SH)
        self.assertNotIn('component.createObject(', SH)
        for forbidden in ('sudo ', 'pacman -S', 'systemctl --user restart',
                          'systemctl --user daemon-reload', 'dms restart',
                          'dms plugins install', 'chatgpt.com', 'WebEngineView'):
            self.assertNotIn(forbidden, SH)


if __name__ == "__main__":
    unittest.main()
