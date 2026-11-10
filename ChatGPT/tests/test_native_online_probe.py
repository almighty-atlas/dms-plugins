"""Static opt-in and privacy assertions for the public ChatGPT popup probe."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
WIDGET = (ROOT / "Widget.qml").read_text()
RUNNER = (ROOT / "run_native_popout.sh").read_text()

class PublicChatGptProbeTests(unittest.TestCase):
    def test_offline_is_default_with_one_exact_url(self):
        self.assertIn('onlineProbe: Quickshell.env("DMS_NATIVE_ONLINE_PROBE") === "1"', WIDGET)
        self.assertIn('if (root.onlineProbe)', WIDGET)
        self.assertIn('url = "https://chatgpt.com/";', WIDGET)
        self.assertIn('loadHtml(', WIDGET)
        self.assertEqual(WIDGET.count("https://"), 1)
        self.assertIn("DMS_NATIVE_PUBLIC_SITE_LOAD_SUCCEEDED", WIDGET)
        self.assertIn("DMS_NATIVE_PUBLIC_SITE_LOAD_FAILED", WIDGET)

    def test_online_has_own_off_the_record_profile(self):
        section = WIDGET.split("WebEngineProfilePrototype {\n        id: publicPageProfileFactory")[1].split("    }", 1)[0]
        self.assertNotIn("storageName", section)
        self.assertIn("publicPageProfileFactory.instance()", WIDGET)
        self.assertIn("profileFactory.instance()", WIDGET)
        self.assertIn("permission.deny()", WIDGET)
        self.assertNotIn("runJavaScript(", WIDGET)
        self.assertNotIn("WebChannel", WIDGET)

    def test_named_consent_profile_is_separate(self):
        self.assertIn('persistenceProbe: Quickshell.env("DMS_NATIVE_PERSISTENCE_PROBE") === "1"', WIDGET)
        self.assertIn('id: consentProfileFactory', WIDGET)
        self.assertIn('storageName: "dms-chatgpt-consent-probe-v01"', WIDGET)
        self.assertIn('persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies', WIDGET)
        self.assertIn('consentProfileFactory.instance()', WIDGET)
        self.assertIn('DMS_NATIVE_PROFILE_CONFIG_INVALID', WIDGET)
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--persistent-chatgpt" ]]', RUNNER)
        self.assertIn('DMS_NATIVE_PERSISTENCE_PROBE="$persistent"', RUNNER)
        self.assertIn('DO NOT SIGN IN', RUNNER)

    def test_opt_in_login_has_distinct_persistent_profile(self):
        self.assertIn('authProbe: Quickshell.env("DMS_NATIVE_AUTH_PROBE") === "1"', WIDGET)
        self.assertIn('id: authProfileFactory', WIDGET)
        self.assertIn('storageName: "dms-chatgpt-auth-probe-v01"', WIDGET)
        self.assertIn('authProfileFactory.instance()', WIDGET)
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--auth-chatgpt" ]]', RUNNER)
        self.assertIn('DMS_NATIVE_AUTH_PROBE="$auth"', RUNNER)
        self.assertIn('duration=300s', RUNNER)
        self.assertIn('dms-chatgpt-native-auth-probe', RUNNER)
        self.assertIn('do not share credentials', RUNNER)

    def test_runner_requires_explicit_opt_in(self):
        self.assertIn('if [[ "$#" == 0 ]]', RUNNER)
        self.assertIn('elif [[ "$#" == 1 && "$1" == "--public-chatgpt" ]]', RUNNER)
        self.assertIn('DMS_NATIVE_ONLINE_PROBE="$online"', RUNNER)
        self.assertIn('DO NOT SIGN IN', RUNNER)
        self.assertIn("/usr/bin/env -i", RUNNER)
        self.assertIn('DMS_SOCKET=""', RUNNER)
        self.assertIn('NIRI_SOCKET=""', RUNNER)
        self.assertIn("dbus-run-session --", RUNNER)
        self.assertIn('timeout --signal=TERM --kill-after=3s "$duration"', RUNNER)
        self.assertIn("duration=60s", RUNNER)

if __name__ == "__main__":
    unittest.main()
