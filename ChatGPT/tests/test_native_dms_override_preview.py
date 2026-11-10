"""Read-only DMS override preview: syntax and safety contract."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
PREVIEW_PATH = ROOT / "preview_dms_override.sh"
TEXT = PREVIEW_PATH.read_text()

class DmsOverridePreviewTests(unittest.TestCase):
    def test_syntax(self):
        subprocess.run(["bash", "-n", str(PREVIEW_PATH)], check=True)

    def test_explicit_preview_only(self):
        self.assertIn('if [[ "$#" != 1 || "$1" != "--preview" ]]', TEXT)
        self.assertIn("DMS_OVERRIDE_PREVIEW_ONLY: NO FILE WRITTEN; NO DAEMON RELOAD; NO RESTART", TEXT)
        self.assertIn("DMS_OVERRIDE_NO_ACTIVATION", TEXT)
        for forbidden in ("systemctl --user restart", "systemctl --user daemon-reload",
                          "sudo ", "tee ", "install ", "mkdir ", "mv ", "cp ",
                          "systemd-run", "systemctl --user edit", "dms restart"):
            self.assertNotIn(forbidden, TEXT)

    def test_live_service_baseline_and_exact_user_scoped_target(self):
        self.assertIn('service=dms.service', TEXT)
        self.assertIn('private_root="$HOME/.local/share/dms-chatgpt-native-host/$version"', TEXT)
        self.assertIn('unit_dir="$HOME/.config/systemd/user/dms.service.d"', TEXT)
        self.assertIn('dropin="$unit_dir/50-chatgpt-private-qs.conf"', TEXT)
        self.assertIn('/usr/lib/systemd/user/dms.service', TEXT)
        self.assertIn('DropInPaths --value', TEXT)
        self.assertIn('MainPID --value', TEXT)
        self.assertIn('readlink -f "/proc/$pid/exe"', TEXT)
        self.assertIn('/usr/bin/dms', TEXT)

    def test_private_host_and_path_validation(self):
        self.assertIn('readelf -d "$private_host"', TEXT)
        self.assertIn('ldd "$private_host"', TEXT)
        self.assertIn('! -O "$f"', TEXT)
        self.assertIn('! "$live_path" =~', TEXT)
        self.assertIn('tr \'\\0\' \'\\n\' < "/proc/$pid/environ"', TEXT)
        self.assertIn('Environment="PATH=%s:%s"', TEXT)
        self.assertIn('DMS_OVERRIDE_ROLLBACK_PLAN', TEXT)

if __name__ == "__main__":
    unittest.main()
