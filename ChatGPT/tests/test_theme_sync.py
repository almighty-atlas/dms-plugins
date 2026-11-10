import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "scripts" / "theme_sync.py"
spec = importlib.util.spec_from_file_location("theme_sync", MODULE)
assert spec is not None and spec.loader is not None
theme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(theme)


class ThemeTests(unittest.TestCase):
    def test_fallback(self):
        colors, origin = theme.read_palette([Path("/nonexistent-dms-theme.json")])
        self.assertEqual(origin, "fallback")
        self.assertTrue(colors["background"].startswith("#"))

    def test_color_validation(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "dms-colors.json"
            path.write_text(json.dumps({"colors": {
                "primary": "#112233",
                "background": "url(evil)",
                "onSurface": "#abc",
            }}))
            colors, source = theme.read_palette([path])
            self.assertEqual(source, str(path))
            self.assertEqual(colors["primary"], "#112233")
            self.assertEqual(colors["background"], theme.DEFAULTS["background"])
            self.assertEqual(colors["onSurface"], theme.DEFAULTS["onSurface"])
            self.assertIn('@-moz-document domain("chatgpt.com")', theme.render_css(colors))

    def test_scoped_profile(self):
        with tempfile.TemporaryDirectory() as temp:
            profile = Path(temp) / "profile"
            theme.sync(profile)
            theme.sync(profile)
            css = (profile / "chrome" / "userContent.css").read_text()
            self.assertIn("chatgpt.com", css)
            user = (profile / "user.js").read_text()
            self.assertEqual(user.count("toolkit.legacyUserProfileCustomizations"), 1)


if __name__ == "__main__":
    unittest.main()
