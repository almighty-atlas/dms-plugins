import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import theme_sync as theme
from runtime import Failure


class ThemeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, {"XDG_DATA_HOME": str(self.root / "data"),
                                          "XDG_CACHE_HOME": str(self.root / "cache")})
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_fallback(self):
        colors, origin = theme.read_palette([Path("/nonexistent-dms-theme.json")])
        self.assertEqual(origin, "fallback")
        self.assertEqual(colors, theme.DEFAULTS)

    def test_actual_dms_cache_dark_light(self):
        payload = json.loads((Path(__file__).parent / "fixtures/dms-colors.json").read_text())
        dark, mode = theme.parse_palette(payload)
        self.assertEqual(mode, "dark")
        self.assertEqual(dark["surfaceContainer"], "#211f26")
        self.assertEqual(dark["onSurface"], "#e6e0e9")
        light, mode = theme.parse_palette(payload, "light")
        self.assertEqual(light["background"], "#fef7ff")
        self.assertEqual(light["onSurface"], "#1d1b20")
        self.assertEqual(mode, "light")

    def test_live_theme_wins_and_normalizes(self):
        colors, mode = theme.parse_palette({"mode": "light", "colors": {
            "primary": "#ABCDEF", "surfaceText": "#123456", "primaryText": "#ffffff"}})
        self.assertEqual(colors["primary"], "#abcdef")
        self.assertEqual(colors["onSurface"], "#123456")
        self.assertEqual(colors["background"], theme.LIGHT["background"])
        self.assertEqual(mode, "light")

    def test_color_validation_and_empty_caches(self):
        path = self.root / "colors.json"
        for payload in ([], {}, {"colors": []}, {"mode": "invalid"}, {"primary": "#abc"}):
            path.write_text(json.dumps(payload))
            self.assertEqual(theme.read_palette([path])[1], "fallback")
        path.write_text("not json")
        self.assertEqual(theme.read_palette([path])[1], "fallback")
        path.write_text(json.dumps({"colors": {"primary": "#112233", "background": "url(evil)",
                                                "onSurface": "#12345678"}}))
        colors, source = theme.read_palette([path])
        self.assertEqual(source, str(path))
        self.assertEqual(colors["primary"], "#112233")
        self.assertEqual(colors["background"], theme.DEFAULTS["background"])
        self.assertEqual(colors["onSurface"], theme.DEFAULTS["onSurface"])

    def test_css_scope_and_no_hidden_or_repositioned_controls(self):
        for colors, mode in ((theme.DEFAULTS, "dark"), (theme.LIGHT, "light")):
            css = theme.render_css(colors, mode)
            self.assertIn('@-moz-document url-prefix("https://chatgpt.com/")', css)
            self.assertIn(f"color-scheme: {mode}", css)
            self.assertEqual(css.count("{"), css.count("}"))
            for forbidden in ("display:", "visibility:", "position:", "overflow:", "pointer-events:",
                              "auth.openai.com", "!important; width:", "button {"):
                self.assertNotIn(forbidden, css)
        with self.assertRaises(ValueError):
            theme.render_css(dict(theme.DEFAULTS, primary="red; }"))

    def test_authenticated_chatgpt_black_surface_override(self):
        # Real desktop inspector: html.chatgpt-theme and its MAIN were black,
        # even though BODY already had the correct DMS background.
        for colors, mode in ((theme.DEFAULTS, "dark"), (theme.LIGHT, "light")):
            css = theme.render_css(colors, mode)
            self.assertIn("html.chatgpt-theme,\n  html.chatgpt-theme main {", css)
            self.assertIn("background-color: var(--dms-background) !important;", css)
            self.assertNotIn("MainContentSurface-EnuIYE", css)
            self.assertNotIn("_R_ldj6nl9iqr7dcchej9arad5_", css)

    def test_authenticated_chat_composer_sidebar_and_code_surfaces(self):
        # Two sanitized DOM exports (451 px viewport) found these stable
        # semantic selectors. No chat text or raw exports are committed.
        for colors, mode in ((theme.DEFAULTS, "dark"), (theme.LIGHT, "light")):
            css = theme.render_css(colors, mode)
            for selector in (
                "html.chatgpt-theme aside.app-shell-left-panel",
                "html.chatgpt-theme aside .sidebar-item:hover",
                "html.chatgpt-theme .bg-surface",
                'html.chatgpt-theme form:has(.ProseMirror[role="textbox"])',
                "html.chatgpt-theme .bg-composer-primary",
                "html.chatgpt-theme .bg-user-message",
                "html.chatgpt-theme main .chatgpt-code-scrollport",
            ):
                self.assertIn(selector, css)
            # No build-generated class hashes or individual DOM IDs.
            for volatile in ("MainContentSurface-EnuIYE", "CodeBlock-zu1QM3",
                             "Root-iW7ipz", "_R_ldj6nl9iqr7dcchej9arad5_"):
                self.assertNotIn(volatile, css)
            self.assertIn("color-mix(in srgb, var(--dms-primary)", css)

    def test_code_block_shell_and_header_use_dms_surface(self):
        # Authenticated DOM capture: code shells had rgb(48, 48, 48)
        # and contained .chatgpt-code-scrollport; headers were direct
        # children with stable utility classes. Avoid generated CSS hashes.
        for colors, mode in ((theme.DEFAULTS, "dark"), (theme.LIGHT, "light")):
            css = theme.render_css(colors, mode)
            outer = "html.chatgpt-theme main .border-subtle.contain-inline-size:has(.chatgpt-code-scrollport)"
            self.assertIn(outer + " {", css)
            self.assertIn(outer + " > .flex.items-center.font-sans.select-none {", css)
            self.assertIn("background-color: var(--dms-surfaceContainer) !important;", css)
            self.assertNotIn("ActionBar-KWWAct", css)
            self.assertNotIn("Root-iW7ipz", css)

    def test_idempotent_sync_and_reversible_settings(self):
        theme.sync()
        profile = theme.profile_path()
        (profile / "user.js").write_text((profile / "user.js").read_text() + 'user_pref("my.custom", true);\n')
        theme.sync()
        before = (profile / "chrome/userContent.css").stat().st_mtime_ns
        theme.sync()
        self.assertEqual((profile / "chrome/userContent.css").stat().st_mtime_ns, before)
        self.assertEqual((profile / "user.js").read_text().count("toolkit.legacyUserProfileCustomizations"), 1)
        self.assertIn('"my.custom", true', (profile / "user.js").read_text())
        theme.sync(enabled=False, compact=False)
        self.assertNotIn("@-moz-document", (profile / "chrome/userContent.css").read_text())
        self.assertIn('"zen.view.compact.enable-at-startup", false', (profile / "user.js").read_text())
        self.assertEqual(profile.stat().st_mode & 0o777, 0o700)

    def test_background_sync_does_not_create_profile(self):
        self.assertEqual(theme.sync(create=False), "not-created")
        self.assertFalse((self.root / "data/dms-chatgpt/zen-profile").exists())

    def test_live_snapshot_survives_terminal_launch(self):
        theme.sync({"mode": "light", "colors": {"primary": "#123456"}})
        theme.sync()
        css = (theme.profile_path() / "chrome/userContent.css").read_text()
        self.assertIn("--dms-primary: #123456", css)
        self.assertIn("color-scheme: light", css)

    def test_light_cache_mode_and_corrupt_snapshot_fallback(self):
        path = theme.cache_paths()[0]
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({"mode": "light", "colors": {"light": {"primary": "#123456"}}}))
        theme.sync()
        css = (theme.profile_path() / "chrome/userContent.css").read_text()
        self.assertIn("color-scheme: light", css)
        (theme.data_dir() / "theme.json").write_text("broken")
        theme.sync()
        self.assertIn("color-scheme: light", (theme.profile_path() / "chrome/userContent.css").read_text())

    def test_symlink_and_unknown_profile_refused(self):
        root = theme.data_dir()
        profile = root / "zen-profile"
        profile.symlink_to(self.root)
        with self.assertRaises(Failure):
            theme.sync()
        profile.unlink()
        profile.mkdir()
        profile.chmod(0o755)
        (profile / "user.js").write_text("normal profile")
        with self.assertRaises(Failure):
            theme.sync()
        self.assertEqual((profile / "user.js").read_text(), "normal profile")
        self.assertEqual(profile.stat().st_mode & 0o777, 0o755)

    def test_managed_file_symlink_refused(self):
        theme.sync()
        css = theme.profile_path() / "chrome/userContent.css"
        css.unlink()
        victim = self.root / "victim"
        victim.write_text("unchanged")
        css.symlink_to(victim)
        with self.assertRaises(Failure):
            theme.sync()
        self.assertEqual(victim.read_text(), "unchanged")

    def test_scaffold_upgrade(self):
        profile = theme.data_dir() / "zen-profile"
        (profile / "chrome").mkdir(parents=True)
        (profile / "chrome/userContent.css").write_text("/* Generated by dms-chatgpt theme_sync.py. Old */")
        theme.sync()
        self.assertTrue((profile / ".dms-chatgpt-profile").exists())
