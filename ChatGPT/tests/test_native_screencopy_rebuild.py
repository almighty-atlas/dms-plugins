"""Safety contracts for rebuilding the private argc=1 host with Screencopy."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
CONFIG = ROOT / "prepare_quickshell_dms_screencopy.sh"
VERIFY = ROOT / "verify_quickshell_screencopy.sh"
QML = ROOT / "ScreencopyViewImportProbe.qml"
BUILD = CONFIG.read_text()
PROBE = VERIFY.read_text()
FIXTURE = QML.read_text()


class NativeScreencopyRebuildTests(unittest.TestCase):
    def test_new_scripts_parse_without_execution(self):
        for path in (CONFIG, VERIFY):
            with self.subTest(script=path.name):
                subprocess.run(["bash", "-n", str(path)], check=True)

    def test_rebuild_is_pinned_and_separate_from_original(self):
        self.assertIn('build_dir="$root/build-dms-screencopy-v01"', BUILD)
        self.assertIn('source_dir="$root/source"', BUILD)
        self.assertIn("9b0f339b19057f4731bf3b48293307d7ef241671", BUILD)
        self.assertIn('status --porcelain', BUILD)
        self.assertIn('original.replace(before, after)', BUILD)
        self.assertIn('cached_src" != "$source_dir', BUILD)
        self.assertNotIn('build_dir="$root/build-dms"', BUILD)

    def test_screencopy_and_critical_dms_modules_compiled(self):
        required = (
            "WAYLAND", "WAYLAND_WLR_LAYERSHELL",
            "WAYLAND_SESSION_LOCK", "WAYLAND_TOPLEVEL_MANAGEMENT",
            "SCREENCOPY", "SCREENCOPY_ICC", "SCREENCOPY_WLR",
            "SCREENCOPY_HYPRLAND_TOPLEVEL",
            "I3", "I3_IPC", "HYPRLAND", "HYPRLAND_IPC",
            "BLUETOOTH", "SERVICE_MPRIS", "SERVICE_NOTIFICATIONS",
            "SERVICE_PAM", "SERVICE_PIPEWIRE", "SERVICE_POLKIT",
            "SERVICE_STATUS_NOTIFIER", "SERVICE_UPOWER",
        )
        for name in required:
            self.assertIn("-D" + name + "=ON", BUILD, name)
        self.assertNotIn("-DSCREENCOPY=OFF", BUILD)
        self.assertIn('CMakeCache.txt', BUILD)
        self.assertIn("DMS_SCREENCOPY_FLAG_CONFIRMED: ON", BUILD)

    def test_screencopy_dependency_preflight(self):
        self.assertIn('pkg-config --exists "$module"', BUILD)
        self.assertIn("gbm libpipewire-0.3", BUILD)
        self.assertIn("/usr/include/vulkan/vulkan_core.h", BUILD)

    def test_isolated_probe_uses_real_screencopy_type(self):
        self.assertIn("import Quickshell.Wayland", FIXTURE)
        self.assertIn("ScreencopyView {", FIXTURE)
        self.assertIn("captureSource: null", FIXTURE)
        self.assertIn("live: false", FIXTURE)
        self.assertIn("DMS_SCREENCOPY_QML_READY", FIXTURE)
        self.assertIn('"$binary" --path "$fixture"', PROBE)
        self.assertIn("DMS_SCREENCOPY_QML_READY", PROBE)
        self.assertIn('dbus-run-session --', PROBE)
        self.assertIn('DMS_SOCKET=""', PROBE)
        self.assertIn('NIRI_SOCKET=""', PROBE)
        self.assertIn('8s', PROBE)

    def test_no_production_changes_or_account_login(self):
        for source in (BUILD, PROBE):
            for forbidden in (
                "sudo ", "pacman -S", "cmake --install", "systemctl --user restart",
                "systemctl edit", "dms restart", "dms plugins install",
                "pkill", "killall", "chatgpt.com", "auth-probe", "WebEngineView",
            ):
                self.assertNotIn(forbidden, source)
        self.assertIn("DMS_SCREENCOPY_NO_LIVE_DMS_CHANGES", PROBE)
        self.assertIn("DMS_SCREENCOPY_ORIGINAL_BUILD_UNCHANGED", BUILD)


if __name__ == "__main__":
    unittest.main()
