"""Offline tests for the optional v0.2 Qt WebEngine diagnostics."""
import importlib.util
from pathlib import Path
import unittest

PATH = Path(__file__).resolve().parents[1] / "probes/webengine/preflight.py"
spec = importlib.util.spec_from_file_location("webengine_probe_preflight", PATH)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class PreflightTests(unittest.TestCase):
    def snapshot(self, env=None, **kwargs):
        return probe.snapshot(env=env if env is not None else
                              {"WAYLAND_DISPLAY": "wayland-1"},
                              versions=kwargs.get("versions", lambda _: "6.11.2"),
                              which=kwargs.get("which", lambda _: "/usr/bin/tool"),
                              process_exists=kwargs.get("process_exists", lambda: True))

    def test_ready_is_not_proof_of_dms_host_support(self):
        result = self.snapshot()
        self.assertEqual(result["standalone_prerequisites"], "READY_TO_PROBE")
        self.assertEqual(result["quickshell_embedded_webengine"], "UNVERIFIED")
        self.assertNotIn("wayland-1", str(result))

    def test_missing_package(self):
        result = self.snapshot(versions=lambda p: None if p == "qt6-webengine" else "6.11.2")
        self.assertEqual(result["standalone_prerequisites"], "MISSING_DEPENDENCIES")

    def test_headless(self):
        self.assertEqual(self.snapshot(env={})["standalone_prerequisites"],
                         "MISSING_DEPENDENCIES")

    def test_sandbox_overrides_block_probe(self):
        for var in ({"QTWEBENGINE_DISABLE_SANDBOX": "1"},
                    {"QTWEBENGINE_CHROMIUM_FLAGS": "--no-sandbox"},
                    {"QTWEBENGINE_CHROMIUM_FLAGS": "--no-sandbox=true"}):
            result = self.snapshot(env={"WAYLAND_DISPLAY": "wayland-1", **var})
            self.assertEqual(result["standalone_prerequisites"], "BLOCKED_UNSAFE")
            self.assertNotIn("QTWEBENGINE_CHROMIUM_FLAGS", str(result))

    def test_explicit_safe_sandbox_flag(self):
        self.assertFalse(probe.sandbox_disabled(
            {"QTWEBENGINE_DISABLE_SANDBOX": "false", "QTWEBENGINE_CHROMIUM_FLAGS": "--disable-gpu"}))

    def test_online_probe_is_explicit_ephemeral_and_first_party(self):
        qml = PATH.with_name("ChatGPTPageProbe.qml").read_text()
        self.assertIn('url: "https://chatgpt.com/"', qml)
        self.assertIn("offTheRecord: true", qml)
        self.assertIn("profile: temporaryProfile", qml)
        self.assertNotIn("persistentStoragePath", qml)
        self.assertNotIn("runJavaScript(", qml)
        self.assertNotIn("WebChannel", qml)
        self.assertNotIn("Zen", qml.split("import QtQuick")[1])
        self.assertIn("do not sign in", qml)

    def test_offline_qml_and_early_initialization(self):
        qml = PATH.with_name("Probe.qml").read_text()
        self.assertIn("loadHtml(", qml)
        self.assertNotIn("https://", qml)
        source = PATH.with_name("main.cpp").read_text()
        self.assertLess(source.index("QtWebEngineQuick::initialize();"),
                        source.index("QGuiApplication app("))
        self.assertIn("Qt::AA_ShareOpenGLContexts", source)


if __name__ == "__main__":
    unittest.main()
