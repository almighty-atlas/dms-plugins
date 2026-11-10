"""Source contracts for a safely isolated DMS-capable Quickshell configure."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
SCRIPT = (ROOT / "prepare_quickshell_dms.sh").read_text()

class DmsHostBuildTests(unittest.TestCase):
    def test_safety_and_source_patch(self):
        self.assertIn("set -euo pipefail", SCRIPT)
        self.assertIn('build_dir="$root/build-dms"', SCRIPT)
        self.assertIn("9b0f339b19057f4731bf3b48293307d7ef241671", SCRIPT)
        self.assertIn("original.replace(before, after)", SCRIPT)
        self.assertIn("status --porcelain", SCRIPT)
        for forbidden in ("sudo ", "pacman -S", "cmake --install",
                          "systemctl ", "dms restart", "dms plugins install"):
            self.assertNotIn(forbidden, SCRIPT)

    def test_all_missing_module_families_enabled(self):
        enabled = set(re.findall(r"-D([A-Z][A-Z0-9_]*)=ON\b", SCRIPT))
        required = {"BLUETOOTH", "HYPRLAND", "I3", "SERVICE_MPRIS",
                    "SERVICE_NOTIFICATIONS", "SERVICE_PAM", "SERVICE_PIPEWIRE",
                    "SERVICE_POLKIT", "SERVICE_STATUS_NOTIFIER", "SERVICE_UPOWER"}
        self.assertTrue(required <= enabled, required - enabled)
        self.assertIn("WAYLAND_WLR_LAYERSHELL", enabled)
        self.assertIn("HYPRLAND_IPC", enabled)
        self.assertIn("I3_IPC", enabled)

    def test_noninstalling_dependency_preflight(self):
        for module in ("libpipewire-0.3", "polkit-agent-1", "polkit-gobject-1"):
            self.assertIn(module, SCRIPT)
        self.assertIn('pkg-config --exists "$module"', SCRIPT)

if __name__ == "__main__":
    unittest.main()
