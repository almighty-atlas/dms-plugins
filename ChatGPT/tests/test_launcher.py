import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import launcher
import runtime
import theme_sync

WINDOW = {"id": 41, "app_id": "dms-chatgpt", "pid": 123, "title": "ChatGPT",
          "workspace_id": 1, "is_floating": False, "is_focused": False}


class IsolatedEnvironment(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, {"XDG_DATA_HOME": str(self.root / "data"),
                                          "XDG_CACHE_HOME": str(self.root / "cache")})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.args = launcher.parser().parse_args([])


class LauncherTests(IsolatedEnvironment):
    def test_discovery_all_binary_names(self):
        for name in launcher.ZEN_NAMES:
            with patch("launcher.shutil.which", side_effect=lambda n: "/bin/" + n if n == name else None):
                self.assertEqual(launcher.find_zen(), "/bin/" + name)
        with patch("launcher.shutil.which", return_value=None), self.assertRaises(runtime.Failure):
            launcher.find_zen()

    def test_identity_never_uses_title_alone(self):
        normal = dict(WINDOW, app_id="zen", id=2)
        popup = dict(WINDOW, title="Sign in", id=3)
        self.assertIsNone(launcher.choose_window([normal]))
        self.assertEqual(launcher.choose_window([normal, popup, WINDOW])["id"], 41)

    def test_identity_pid_fallback_when_zen_ignores_name(self):
        normal = dict(WINDOW, app_id="zen", id=2, pid=456)
        dedicated = dict(WINDOW, app_id="zen", title="Sign in")
        self.assertEqual(launcher.choose_window([normal, dedicated], [123])["id"], 41)
        self.assertIsNone(launcher.choose_window([normal, dedicated], [999]))

    def test_proc_identity_only_reads_same_user_zen_arguments(self):
        profile = self.root / "dedicated profile"
        for pid, name, args in ((1, "zen", ["zen", "--profile", str(profile)]),
                                (2, "zen", ["zen", "--profile", "/normal"]),
                                (3, "unrelated", ["unrelated", "--profile", str(profile)])):
            directory = self.root / str(pid)
            directory.mkdir()
            (directory / "comm").write_text(name)
            (directory / "cmdline").write_bytes(b"\0".join(os.fsencode(a) for a in args))
        self.assertEqual(launcher.profile_processes(profile, self.root), [1])

    def test_focus_no_spawn_even_after_dms_restart(self):
        with patch("launcher.niri_query", return_value=[WINDOW]), patch("launcher.find_zen", return_value="zen"), \
                patch("launcher.action") as action, patch("launcher.spawn") as spawn:
            self.assertEqual(launcher.launch(self.args)["status"], "focused")
            action.assert_called_once_with("focus-window", 41)
            spawn.assert_not_called()

    def test_failed_ipc_never_spawns(self):
        with patch("launcher.niri_query", side_effect=runtime.Failure("Niri missing")), \
                patch("launcher.spawn") as spawn, self.assertRaises(runtime.Failure):
            launcher.launch(self.args)
        spawn.assert_not_called()

    def test_running_profile_without_window_never_spawns(self):
        with patch("launcher.niri_query", return_value=[]), patch("launcher.find_zen", return_value="zen"), \
                patch("launcher.profile_processes", return_value=[99]), patch("launcher.spawn") as spawn, \
                self.assertRaisesRegex(runtime.Failure, "ohne erkanntes Fenster"):
            launcher.launch(self.args)
        spawn.assert_not_called()

    def test_spawn_parameters_confirmation_and_geometry(self):
        process = Mock()
        process.poll.return_value = None
        queries = [[], [WINDOW]]
        with patch("launcher.niri_query", side_effect=queries), patch("launcher.find_zen", return_value="/bin/zen"), \
                patch("launcher.command", return_value="--name NAME"), patch("launcher.profile_processes", return_value=[]), \
                patch("launcher.spawn", return_value=process) as spawn, patch("launcher.arrange") as arrange:
            self.assertEqual(launcher.launch(self.args)["status"], "opened")
            self.assertEqual(spawn.call_args.args[0], ["/bin/zen", "--no-remote", "--profile",
                str(theme_sync.profile_path()), "--name", "dms-chatgpt", "--new-window", "https://chatgpt.com/"])
            arrange.assert_called_once_with(WINDOW, "", "top")

    def test_browser_exit_zero_is_not_window_success(self):
        process = Mock()
        process.poll.return_value = 0
        with patch("launcher.niri_query", return_value=[]), patch("launcher.find_zen", return_value="zen"), \
                patch("launcher.command", return_value="--name"), patch("launcher.profile_processes", return_value=[]), \
                patch("launcher.spawn", return_value=process), self.assertRaisesRegex(runtime.Failure, "kein Fenster"):
            launcher.launch(self.args, timeout=0.01)

    def test_existing_mode_never_themes_normal_profile(self):
        self.args.mode = "existing"
        process = Mock()
        process.poll.return_value = 0
        with patch.dict(os.environ, {"NIRI_SOCKET": ""}), patch("launcher.find_zen", return_value="zen"), \
                patch("launcher.shutil.which", return_value="zen"), patch("launcher.spawn", return_value=process) as spawn, \
                patch("launcher.theme_sync.sync") as sync:
            self.assertEqual(launcher.launch(self.args)["status"], "requested")
        spawn.assert_called_once_with(["zen", "--new-window", launcher.URL])
        sync.assert_not_called()
        self.assertFalse((self.root / "data/dms-chatgpt/zen-profile").exists())

    def test_system_mode_requires_xdg_open(self):
        self.args.mode = "system"
        with patch("launcher.shutil.which", return_value=None), patch("launcher.spawn") as spawn, \
                self.assertRaisesRegex(runtime.Failure, "xdg-open"):
            launcher.launch(self.args)
        spawn.assert_not_called()

    def test_regular_focus_requires_saved_identity(self):
        self.args.mode = "existing"
        window = dict(WINDOW, app_id="zen")
        runtime.atomic_write(runtime.data_dir() / "existing-window.json", json.dumps(window))
        with patch.dict(os.environ, {"NIRI_SOCKET": "/fake"}), patch("launcher.shutil.which", return_value="zen"), \
                patch("launcher.niri_query", return_value=[window]), patch("launcher.action") as action, \
                patch("launcher.spawn") as spawn:
            self.assertEqual(launcher.launch(self.args)["status"], "focused")
        action.assert_called_once_with("focus-window", 41)
        spawn.assert_not_called()

    def test_untracked_normal_chatgpt_window_is_not_focused(self):
        self.args.mode = "existing"
        window = dict(WINDOW, app_id="zen")
        with patch.dict(os.environ, {"NIRI_SOCKET": "/fake"}), patch("launcher.shutil.which", return_value="zen"), \
                patch("launcher.find_zen", return_value="zen"), patch("launcher.niri_query", return_value=[window]), \
                patch("launcher.action") as action, patch("launcher.spawn"):
            self.assertEqual(launcher.launch(self.args, timeout=0)["status"], "requested")
        action.assert_not_called()

    def test_command_timeout_does_not_expose_stderr(self):
        with patch("launcher.subprocess.run", side_effect=subprocess.TimeoutExpired("niri", 4, stderr="private title")), \
                self.assertRaises(runtime.Failure) as caught:
            launcher.command(["niri"])
        self.assertNotIn("private title", str(caught.exception))

    def test_malformed_niri_json(self):
        for output in ("invalid", "null", "{}", "[1]", "[null]"):
            with patch("launcher.command", return_value=output), self.assertRaises(runtime.Failure):
                launcher.niri_query("windows")
        with patch("launcher.command", return_value='{"DP-1": {"logical": 5}}'), self.assertRaises(runtime.Failure):
            launcher.niri_query("outputs")

    def test_wait_timeout_no_extra_spawn(self):
        process = Mock()
        process.poll.return_value = None
        with patch("launcher.niri_query", return_value=[]), patch("launcher.find_zen", return_value="zen"), \
                patch("launcher.command", return_value="--name"), patch("launcher.profile_processes", return_value=[]), \
                patch("launcher.spawn", return_value=process) as spawn, self.assertRaisesRegex(runtime.Failure, "kein Fenster"):
            launcher.launch(self.args, timeout=0)
        spawn.assert_called_once()

    def test_geometry_clamps_and_uses_explicit_window_id(self):
        outputs = {"DP-2": {"logical": {"width": 700, "height": 780}}}
        with patch("launcher.niri_query", side_effect=[outputs, [{"id": 1, "output": "DP-2"}]]), \
                patch("launcher.action") as action:
            launcher.arrange(WINDOW, "DP-2", "left")
        calls = [c.args for c in action.call_args_list]
        self.assertIn(("set-window-width", 41, 652), calls)
        self.assertIn(("set-window-height", 41, 684), calls)
        self.assertIn(("move-floating-window", 41, "--x", 24, "--y", 72), calls)
        self.assertIn(("move-window-to-monitor", 41, "--", "DP-2"), calls)

    def test_focus_failure_propagates(self):
        with patch("launcher.command", side_effect=runtime.Failure("failed")), self.assertRaises(runtime.Failure):
            launcher.focus(WINDOW)

    def test_unsafe_window_id_rejected(self):
        for value in (None, -1, True, "41; bad"):
            with self.assertRaises(runtime.Failure):
                launcher.action("focus-window", value)

    def test_spawn_has_no_shell_and_sanitizes_remote_overrides(self):
        with patch.dict(os.environ, {"MOZ_PROFILE": "/normal", "MOZ_NO_REMOTE": "1"}), \
                patch("launcher.subprocess.Popen") as popen:
            launcher.spawn(["zen", "--new-window", launcher.URL])
        kwargs = popen.call_args.kwargs
        self.assertNotIn("shell", kwargs)
        self.assertNotIn("MOZ_PROFILE", kwargs["env"])
        self.assertTrue(kwargs["close_fds"])
        self.assertTrue(kwargs["start_new_session"])


class ExecutableFixtureTests(IsolatedEnvironment):
    """Run real launcher/lock/subprocess handling with local fake Zen + Niri, no desktop."""
    def setUp(self):
        super().setUp()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "windows.json"
        self.state.write_text("[]")
        self.log = self.root / "events.jsonl"
        mock = '''import json, os, sys, time
from pathlib import Path
state = Path(os.environ["MOCK_STATE"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "zen" and args == ["--help"]:
    print("--name NAME --profile PATH --no-remote")
    sys.exit(0)
with open(os.environ["MOCK_LOG"], "a") as stream:
    stream.write(json.dumps([name, args]) + "\\n")
if name == "zen":
    if os.environ.get("MOCK_EXIT"):
        sys.exit(7)
    pending = state.with_suffix(".tmp")
    pending.write_text(json.dumps([{"id": 41, "app_id": "dms-chatgpt", "pid": os.getpid(), "title": "ChatGPT", "workspace_id": 1}]))
    pending.replace(state)
    time.sleep(0.5)
elif "windows" in args:
    print(state.read_text())
elif "outputs" in args:
    print(json.dumps({"DP-1": {"logical": {"width": 1920, "height": 1080}}}))
elif "workspaces" in args:
    print('[{"id": 1, "output": "DP-1"}]')
elif os.environ.get("MOCK_ACTION_FAIL"):
    sys.exit(1)
'''
        for name in ("zen", "niri"):
            file = self.bin / name
            file.write_text(f"#!{sys.executable}\n" + mock)
            file.chmod(0o700)
        self.extra_env = patch.dict(os.environ, {"PATH": str(self.bin), "MOCK_STATE": str(self.state),
                                                "MOCK_LOG": str(self.log), "NIRI_SOCKET": "/fake"})
        self.extra_env.start()
        self.addCleanup(self.extra_env.stop)

    def run_launcher(self):
        return subprocess.run([sys.executable, str(SCRIPTS / "launcher.py")], capture_output=True,
                              text=True, timeout=12)

    def test_real_commands_launch_then_focus(self):
        for expected in ("opened", "focused"):
            result = self.run_launcher()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)["status"], expected)
        events = [json.loads(s) for s in self.log.read_text().splitlines()]
        self.assertEqual(sum(e[0] == "zen" for e in events), 1)
        self.assertTrue(any("focus-window" in e[1] for e in events))

    def test_parallel_clicks_produce_only_one_browser(self):
        commands = [[sys.executable, str(SCRIPTS / "launcher.py")]] * 2
        processes = [subprocess.Popen(c, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for c in commands]
        results = [p.communicate(timeout=12) for p in processes]
        self.assertEqual([p.returncode for p in processes], [0, 0], results)
        events = [json.loads(s) for s in self.log.read_text().splitlines()]
        self.assertEqual(sum(e[0] == "zen" for e in events), 1)

    def test_exit_error_is_reported_and_retry_recovers(self):
        with patch.dict(os.environ, {"MOCK_EXIT": "1"}):
            result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error", json.loads(result.stdout))
        retry = self.run_launcher()
        self.assertEqual(retry.returncode, 0, retry.stdout + retry.stderr)

    def test_focus_command_failure_not_success(self):
        self.state.write_text(json.dumps([WINDOW]))
        with patch.dict(os.environ, {"MOCK_ACTION_FAIL": "1"}):
            result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error", json.loads(result.stdout))
