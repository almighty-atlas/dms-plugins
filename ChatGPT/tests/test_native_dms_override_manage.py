"""Static safety and bash syntax tests for opt-in, timed DMS QS switch."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
MANAGE_PATH = ROOT / "manage_dms_override.sh"
PREVIEW_PATH = ROOT / "preview_dms_override.sh"
SH = MANAGE_PATH.read_text()

class ManagedDmsOverrideTests(unittest.TestCase):
    def test_script_parses_and_has_only_explicit_modes(self):
        for path in (MANAGE_PATH, PREVIEW_PATH):
            with self.subTest(path=path.name):
                subprocess.run(["bash", "-n", str(path)], check=True)
        self.assertIn('mode="${1:-}"', SH)
        for mode in ('"--activate"', '"--confirm"', '"--rollback"'):
            self.assertIn(mode, SH)
        self.assertIn('if [[ ! -t 0 ]]', SH)
        self.assertIn("Type ACTIVATE to continue", SH)
        self.assertIn('if [[ "$answer" != ACTIVATE ]]', SH)

    def test_candidate_is_versioned_and_hash_pinned(self):
        self.assertIn("9b0f339-argc1-v01", SH)
        self.assertIn("expected_host_sha=af356f3885e51fa0f4a40697648cc97ca19e24342ca990c01a340d34092f696a", SH)
        self.assertIn('preview_dms_override.sh', SH)
        self.assertIn('DMS_OVERRIDE_PREVIEW_CHECKS: PASSED', SH)
        self.assertIn('DMS_OVERRIDE_PREVIEW_DESTINATION: $dropin', SH)
        self.assertIn('if [[ "$shown_ini" != "$expected_ini" ]]', SH)

    def test_timer_installed_before_override_or_service_restart(self):
        timer = SH.index('systemd-run --user --collect --on-active=10min')
        write = SH.index('ln -- "$tmp" "$dropin"')
        reload = SH.index('systemctl --user daemon-reload', write)
        restart = SH.index('systemctl --user restart dms.service', write)
        self.assertLess(timer, write)
        self.assertLess(write, reload)
        self.assertLess(reload, restart)
        self.assertIn('if ! systemctl --user is-active --quiet "$timer"', SH)
        self.assertIn('"$persistent" --rollback', SH)

    def test_rollback_is_independent_of_private_binary(self):
        begin = SH.index('rollback() {')
        end = SH.index('\nif [[ "$mode" == "--rollback" ]]', begin)
        function = SH[begin:end]
        self.assertNotIn("expected_host_sha", function)
        self.assertNotIn('! -x "$host"', function)
        self.assertIn('sha256sum "$dropin"', function)
        self.assertIn('rm -- "$dropin"', function)
        self.assertIn('systemctl --user daemon-reload', function)
        self.assertIn('systemctl --user restart dms.service', function)

    def test_confirm_requires_real_supervised_private_frontend(self):
        self.assertIn('pgrep -P "$pid"', SH)
        self.assertIn('readlink -f "/proc/$child/exe"', SH)
        self.assertIn('DMS_CONFIRM_BLOCKED', SH)
        self.assertIn('systemctl --user stop "$timer"', SH)
        self.assertIn('DMS_SWITCH_MANUAL_ROLLBACK:', SH)

    def test_cannot_replace_global_packages_or_other_overrides(self):
        self.assertIn('dropin="$dropdir/50-chatgpt-private-qs.conf"', SH)
        self.assertIn('ln -- "$tmp" "$dropin"', SH)
        self.assertIn('! -O "$dropin"', SH)
        for forbidden in ('sudo ', 'pacman -S', 'pkill ', 'killall ',
                          'rm -rf ', 'rm /usr', 'cp /usr',
                          'systemctl --system', 'QTWEBENGINE_DISABLE_SANDBOX=1'):
            self.assertNotIn(forbidden, SH)

if __name__ == "__main__":
    unittest.main()
