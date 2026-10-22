"""Offline Python entry point; behavioral coverage runs the actual JS/QML in Qt 6.

DMS services/widgets and Quickshell processes are mocked in the Qt tests.
CLI tests use real executables and generated local WAV fixtures, never YouTube.
"""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "YouTube"
MODEL = (PLUGIN / "js/Companion.js").read_text()
CONTROLLER = (PLUGIN / "components/CompanionController.qml").read_text()
QT = pathlib.Path("/usr/lib/qt6/bin")


class ContractTest(unittest.TestCase):
    def test_manifest_and_registry_match(self):
        manifest = json.loads((PLUGIN / "plugin.json").read_text())
        registry = json.loads((ROOT / "plugins/youtube-search.json").read_text())
        self.assertEqual("youtubeSearch", manifest["id"])
        self.assertEqual(manifest["id"], registry["id"])
        self.assertEqual(manifest["name"], registry["name"])
        self.assertEqual("YouTube", registry["path"])
        self.assertEqual("0.2.0", manifest["version"])
        self.assertEqual("./Settings.qml", manifest["settings"])
        self.assertTrue({"settings_read", "settings_write"}.issubset(manifest["permissions"]))

    def test_process_guards(self):
        self.assertIn('"/usr/bin/env", "yt-dlp"', MODEL)
        self.assertIn('"/usr/bin/env", "mpv"', MODEL)
        self.assertIn("25000, root", CONTROLLER)
        self.assertIn("interval: 30000", CONTROLLER)
        self.assertIn("root.activeRequestId !== token", CONTROLLER)
        self.assertIn("Component.onDestruction", CONTROLLER)
        for code in (124, 126, 127):
            self.assertIn("code === " + str(code), MODEL)
        for path in PLUGIN.rglob("*.qml"):
            if "tests" not in path.parts:
                self.assertNotIn('"-c"', path.read_text(), str(path))

    @unittest.skipUnless((QT / "qmltestrunner").exists(), "Qt 6 qmltestrunner unavailable")
    def test_qt6_behavior(self):
        result = subprocess.run(
            [str(QT / "qmltestrunner"), "-input", str(PLUGIN / "tests/qml"),
             "-import", str(PLUGIN / "tests/imports")],
            env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("0 failed", result.stdout)
        # Only explicitly tested diagnostics may warn, never QML binding errors.
        unexpected = [line for line in result.stdout.splitlines()
                      if "QWARN" in line and "qml: youtubeSearch:" not in line]
        self.assertEqual([], unexpected, result.stdout)

    @unittest.skipUnless((QT / "qmllint").exists(), "Qt 6 qmllint unavailable")
    def test_qml_lint_components_with_mock_host(self):
        result = subprocess.run(
            [str(QT / "qmllint"), "-I", str(PLUGIN / "tests/imports"),
             *map(str, sorted((PLUGIN / "components").glob("*.qml")))],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertEqual("", result.stdout)


class CliSmokeTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("mpv"), "mpv unavailable")
    def test_mpv_audio_and_ordered_multiple_arguments(self):
        with tempfile.TemporaryDirectory(prefix="youtube-test-") as temporary:
            paths = [pathlib.Path(temporary) / name for name in ("first.wav", "second.wav")]
            for path in paths:
                with wave.open(str(path), "wb") as output:
                    output.setnchannels(1)
                    output.setsampwidth(2)
                    output.setframerate(8000)
                    output.writeframes(b"\x00\x00" * 800)
            command = ["/usr/bin/env", "mpv", "--no-config", "--no-video",
                       "--audio-display=no", "--force-window=no", "--ytdl-format=bestaudio/best",
                       "--ao=null", "--vo=null", "--term-playing-msg=ENTRY:${filename}",
                       "--", *map(str, paths)]
            result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=15)
            self.assertEqual(0, result.returncode, result.stdout)
            self.assertIn("ENTRY:first.wav", result.stdout)
            self.assertIn("ENTRY:second.wav", result.stdout)
            self.assertLess(result.stdout.index("ENTRY:first.wav"), result.stdout.index("ENTRY:second.wav"))

    @unittest.skipUnless(shutil.which("yt-dlp"), "yt-dlp unavailable")
    def test_ytdlp_env_launch(self):
        result = subprocess.run(["/usr/bin/env", "yt-dlp", "--ignore-config", "--version"],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertRegex(result.stdout, r"\d{4}\.\d{2}\.\d{2}")

    def test_missing_executable_status(self):
        result = subprocess.run(["/usr/bin/env", "youtube-companion-nonexistent-test-binary"],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        self.assertEqual(127, result.returncode)


if __name__ == "__main__":
    unittest.main()
