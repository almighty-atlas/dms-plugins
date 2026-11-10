"""Mock DMS IPC tests: no live daemon, compositor, system bus, or network."""
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1] / "experiments/native-popout"
SERVER = ROOT / "mock_dms_backend.py"
OUTER = ROOT / "run_dms_headless_niri.sh"
INNER = ROOT / "run_dms_headless_niri_inner.sh"
OUTER_TEXT = OUTER.read_text()
INNER_TEXT = INNER.read_text()
SERVER_TEXT = SERVER.read_text()
SPEC = importlib.util.spec_from_file_location("mock_dms_backend", SERVER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MockDmsBackendTests(unittest.TestCase):
    def test_protocol_subscribe_and_shell_ready(self):
        greeting, ready = MODULE.response({"method": "subscribe", "params": {"services": ["network"]}})
        self.assertFalse(ready)
        self.assertEqual(greeting["result"]["service"], "server")
        self.assertEqual(greeting["result"]["data"]["apiVersion"], 38)
        self.assertEqual(greeting["result"]["data"]["capabilities"], [])
        reply, ready = MODULE.response({"method": "shell.ready", "id": 7, "params": {"pid": 12345}})
        self.assertTrue(ready)
        self.assertEqual(reply["id"], 7)
        self.assertTrue(reply["result"]["accepted"])
        bad, ready = MODULE.response({"method": "shell.ready", "id": 8, "params": {}})
        self.assertFalse(ready)
        self.assertIn("error", bad)
        denied, ready = MODULE.response({"method": "loginctl.terminate", "id": 9})
        self.assertFalse(ready)
        self.assertIn("error", denied)

    def test_uses_only_private_socket(self):
        self.assertIn("socket.AF_UNIX", SERVER_TEXT)
        self.assertIn("socket.SOCK_STREAM", SERVER_TEXT)
        self.assertIn('runtime.stat().st_uid != os.getuid()', SERVER_TEXT)
        self.assertIn("0o700", SERVER_TEXT)
        self.assertIn("MAX_LINE = 32768", SERVER_TEXT)
        self.assertIn("DMS_MOCK_SHELL_READY_RECEIVED", SERVER_TEXT)
        for disallowed in ("AF_INET", "subprocess", "urllib", "requests.", "os.system",
                           "systemctl", "pacman -S", "chatgpt.com"):
            self.assertNotIn(disallowed, SERVER_TEXT)

    def test_actual_private_unix_socket_protocol(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp) / "runtime"
            runtime.mkdir(mode=0o700)
            sockpath = runtime / "mock.sock"
            marker = runtime / "ready.marker"
            env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime))
            child = subprocess.Popen(
                [sys.executable, str(SERVER), "--socket", str(sockpath),
                 "--marker", str(marker), "--duration", "4"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, env=env,
            )
            try:
                for _ in range(80):
                    if sockpath.is_socket():
                        break
                    if child.poll() is not None:
                        self.fail("mock backend exited before creating socket")
                    time.sleep(0.05)
                self.assertTrue(sockpath.is_socket())
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                    client.settimeout(2)
                    client.connect(str(sockpath))
                    client.sendall(b'{"method":"subscribe","params":{"services":[]}}\n')
                    response = json.loads(client.recv(2048))
                    self.assertEqual(response["result"]["data"]["apiVersion"], 38)
                    client.sendall(b'{"id":9,"method":"shell.ready","params":{"pid":4321}}\n')
                    response = json.loads(client.recv(2048))
                    self.assertEqual(response["id"], 9)
                    self.assertTrue(response["result"]["accepted"])
                stdout, stderr = child.communicate(timeout=5)
                self.assertEqual(child.returncode, 0, stderr)
                self.assertEqual(marker.read_text().strip(), "DMS_MOCK_SHELL_READY_RECEIVED")
                self.assertIn("DMS_MOCK_SHELL_READY_RECEIVED", stdout)
            finally:
                if child.poll() is None:
                    child.terminate()
                    try:
                        child.communicate(timeout=3)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        child.communicate(timeout=3)

    def test_opt_in_mode_keeps_isolation(self):
        for required in (
            '--mock-backend-probe',
            'mock_backend=0',
            'mock_script="$script_dir/mock_dms_backend.py"',
            'DMS_HEADLESS_DMS_BACKEND: PRIVATE_MOCK_ONLY',
            'WAYLAND_DISPLAY="" NIRI_SOCKET="" DMS_SOCKET="" NOTIFY_SOCKET=""',
            'dbus-run-session --',
            'XDG_RUNTIME_DIR="$private/runtime"',
        ):
            self.assertIn(required, OUTER_TEXT)
        for required in (
            'mock_mode="$5"',
            'mock_marker="$private/runtime/dms-shell-ready.marker"',
            'dms_socket="$private/runtime/dms-mock.sock"',
            'notify_socket="$private/runtime/notify-unused.sock"',
            'DMS_HEADLESS_MOCK_SHELL_READY_RECEIVED: YES',
            'DMS_HEADLESS_BACKEND_READY: MOCK_PROTOCOL_ONLY',
            'trap cleanup_inner EXIT',
            'kill -TERM "$mock_pid"',
            'DMS_SOCKET="$dms_socket" NOTIFY_SOCKET="$notify_socket"',
        ):
            self.assertIn(required, INNER_TEXT)
        for source in (OUTER_TEXT, INNER_TEXT):
            for unsafe in ("sudo ", "pacman -S", "systemctl --user restart",
                           "dms restart", "dms plugins install", "niri --session",
                           "auth-probe", "chatgpt.com"):
                self.assertNotIn(unsafe, source)

    def test_shell_script_syntax(self):
        for path in (OUTER, INNER):
            subprocess.run(["bash", "-n", str(path)], check=True)


if __name__ == "__main__":
    unittest.main()
