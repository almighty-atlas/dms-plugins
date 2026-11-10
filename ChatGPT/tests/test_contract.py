import json
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch

PLUGIN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN / "scripts"))
import manage
from runtime import Failure, locked


class ContractTests(unittest.TestCase):
    def test_manifest_registry_paths_and_permissions(self):
        manifest = json.loads((PLUGIN / "plugin.json").read_text())
        registry = json.loads((PLUGIN.parent / "plugins/chatgpt-web.json").read_text())
        for key in ("id", "name", "capabilities", "author", "dependencies"):
            self.assertEqual(manifest[key], registry[key])
        self.assertRegex(manifest["id"], r"^[a-z][a-zA-Z0-9]*$")
        self.assertEqual(manifest["type"], "widget")
        self.assertEqual(manifest["requires_dms"], ">=2.0.0")
        self.assertEqual(registry["path"], PLUGIN.name)
        self.assertEqual(registry["repo"], "https://github.com/almighty-atlas/dms-plugins")
        for key in ("component", "settings"):
            self.assertTrue((PLUGIN / manifest[key]).is_file())
        self.assertIn("settings_write", manifest["permissions"])
        self.assertNotIn("network", manifest["permissions"])

    def test_qml_contract_and_no_deprecated_icon(self):
        widget = (PLUGIN / "Widget.qml").read_text()
        settings = (PLUGIN / "Settings.qml").read_text()
        for member in ("horizontalBarPill:", "verticalBarPill:", "pillClickAction:", "root.widgetThickness",
                       "root.iconSize", "root.textSize", "Proc.runCommand", "Theme.isLightMode"):
            self.assertIn(member, widget)
        self.assertNotIn("DankIcon", widget)
        self.assertNotIn("sh\", \"-c", widget)
        for key in re.findall(r'settingKey: "(\w+)"', settings):
            self.assertIn(f'setting("{key}"', widget)

    def test_hover_never_launches_external_window(self):
        widget = (PLUGIN / "Widget.qml").read_text()
        # DMS's triggerHoverPopout() invokes pillClickAction on hover by default.
        # Action-only external launchers override the hover path explicitly.
        self.assertRegex(widget, r"function\s+triggerHoverPopout\s*\(\s*\)\s*\{\s*\}")
        self.assertIn("pillClickAction: () => root.openChat(root.parentScreen)", widget)
        self.assertNotIn("pillClickAction: (x, y, width, section, screen)", widget)

    def test_niri_rule_exact_identity_only(self):
        rule = (PLUGIN / "niri-window-rule.kdl.example").read_text()
        self.assertIn('app-id=r#"^dms-chatgpt$"#', rule)
        self.assertNotRegex(rule, r'(?m)^\s*match .*title=')

    def test_local_install_update_uninstall_preserves_profile(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / "plugins"
            profile = Path(temp) / "browser-data"
            profile.write_text("untouched session fixture")
            for operation in ("install", "install", "update"):
                manage.manage(operation, directory)
                self.assertEqual((directory / "chatgptWeb").resolve(), PLUGIN)
            manage.manage("uninstall", directory)
            manage.manage("uninstall", directory)
            self.assertFalse((directory / "chatgptWeb").exists())
            self.assertEqual(profile.read_text(), "untouched session fixture")

    def test_foreign_installation_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            target = directory / "chatgptWeb"
            target.mkdir()
            for operation in ("install", "update", "uninstall"):
                with self.assertRaises(Failure):
                    manage.manage(operation, directory)
            target.rmdir()
            target.symlink_to(directory / "other")
            with self.assertRaises(Failure):
                manage.manage("install", directory)

    def test_same_id_in_other_directory_is_not_installed_twice(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            other = directory / "ChatGPT"
            other.mkdir()
            (other / "plugin.json").write_text('{"id": "chatgptWeb"}')
            with self.assertRaises(Failure):
                manage.manage("install", directory)
            self.assertFalse((directory / "chatgptWeb").exists())

    def test_lock_contention_and_release(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"XDG_DATA_HOME": temp}):
            with locked():
                with self.assertRaises(Failure):
                    with locked(timeout=0):
                        pass
            with locked(timeout=0):
                pass
