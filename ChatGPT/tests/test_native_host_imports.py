"""Deterministic read-only import audit tests; no DMS process spawned."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments" / "native-popout"
spec = importlib.util.spec_from_file_location("dms_native_import_audit", ROOT / "check_host_imports.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class DmsNativeImportAuditTests(unittest.TestCase):
    def test_read_import_statements_with_alias(self):
        source = """
import QtQuick
import Quickshell
import Quickshell.I3 as I3
import Quickshell.Services.SystemTray
// import Quickshell.Services.Pipewire
"""
        result = mod.imports_from_text(source)
        self.assertIn("Quickshell.I3", result)
        self.assertIn("Quickshell.Services.SystemTray", result)
        self.assertIn("Quickshell", result)
        self.assertNotIn("Quickshell.Services.Pipewire", result)

    def test_parse_cmake_bool_flags(self):
        values = mod.read_cmake_bool("I3:BOOL=OFF\nWAYLAND:BOOL=ON\nX11:BOOL=TRUE\nNAME:STRING=OFF\n")
        self.assertEqual(values, {"I3": False, "WAYLAND": True, "X11": True})

    def test_audit_reports_disabled_and_unknown(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "src"
            source.mkdir()
            (source / "test.qml").write_text(
                "import Quickshell.I3\nimport Quickshell.Wayland\nimport Quickshell.Fake\n"
            )
            cache = root / "CMakeCache.txt"
            cache.write_text("I3:BOOL=OFF\nWAYLAND:BOOL=ON\n")
            report = mod.audit(source, cache)
            self.assertEqual(report["status"], "DISABLED_MODULES_FOUND")
            self.assertEqual([r["module"] for r in report["disabled_imports"]], ["Quickshell.I3"])
            self.assertIn("Quickshell.Fake", [r["module"] for r in report["unknown_imports"]])
            self.assertEqual(report["runtime_compatibility"], "NOT_TESTED")

    def test_audit_never_runs_shell(self):
        text = (ROOT / "check_host_imports.py").read_text()
        for forbidden in ("subprocess", "os.system", "quickshell --", "dms restart", "pacman -S"):
            self.assertNotIn(forbidden, text)


if __name__ == "__main__":
    unittest.main()
