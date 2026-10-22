"""Static contract checks for the DMS YouTube search plugin.

Run: python3 -m unittest discover -s YouTube/tests -v
These checks do not replace a live Quickshell integration test.
"""
import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
WIDGET = (ROOT / "YouTube" / "Widget.qml").read_text(encoding="utf-8")


class YouTubeSearchContractTest(unittest.TestCase):
    def test_manifest_and_registry_match(self):
        manifest = json.loads((ROOT / "YouTube" / "plugin.json").read_text())
        registry = json.loads((ROOT / "plugins" / "youtube-search.json").read_text())
        self.assertEqual("youtubeSearch", manifest["id"])
        self.assertEqual(manifest["id"], registry["id"])
        self.assertEqual(manifest["name"], registry["name"])
        self.assertEqual("YouTube", registry["path"])
        self.assertEqual("0.1.2", manifest["version"])
        self.assertEqual("./Widget.qml", manifest["component"])

    def test_command_uses_env_and_no_shell(self):
        self.assertIn('"/usr/bin/env", "yt-dlp"', WIDGET)
        self.assertIn('"ytsearch10:" + query', WIDGET)
        self.assertNotIn('["sh", "-c"', WIDGET)
        self.assertNotIn("Quickshell.Io", WIDGET)

    def test_proc_timeout_and_request_isolation(self):
        self.assertIn("Proc.runCommand(\n                null,", WIDGET)
        self.assertIn("                25000,\n                root\n", WIDGET)
        self.assertIn("interval: 30000", WIDGET)
        self.assertIn("root.searchRequestId !== requestId || root.timedOut", WIDGET)

    def test_diagnostics_preserved(self):
        for code in (124, 126, 127):
            self.assertIn("exitCode === " + str(code), WIDGET)
        self.assertIn("console.warn(\"youtubeSearch: yt-dlp exited", WIDGET)
        self.assertIn("root.consumeResults(output)", WIDGET)

    def test_video_id_is_validated(self):
        self.assertIn("/^[A-Za-z0-9_-]{11}$/", WIDGET)
        self.assertIn("if (!validVideoId(videoId))", WIDGET)


if __name__ == "__main__":
    unittest.main()
