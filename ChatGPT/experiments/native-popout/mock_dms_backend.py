#!/usr/bin/env python3
"""Safe local IPC stub for one isolated DMS shell.ready probe.

Binds only to a caller-owned private XDG_RUNTIME_DIR Unix socket.
Never starts the real daemon, uses network interfaces, or authenticates.
The marker proves receipt of shell.ready by this MOCK, not the real backend.
"""
import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import socket
import stat
import sys
import time

API_VERSION = 38
MAX_LINE = 32768
MAX_BUFFER = 65536
MAX_CLIENTS = 12
STOP = False


def handle_signal(_signum, _frame):
    global STOP
    STOP = True


def check_private_paths(sock_path: Path, marker_path: Path):
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
    if not runtime.is_absolute() or not runtime.is_dir():
        raise ValueError("no private absolute runtime directory")
    if runtime.is_symlink() or runtime.stat().st_uid != os.getuid():
        raise ValueError("runtime directory not owned")
    if stat.S_IMODE(runtime.stat().st_mode) != 0o700:
        raise ValueError("runtime directory must be mode 0700")
    for path in (sock_path, marker_path):
        if not path.is_absolute() or path.parent != runtime:
            raise ValueError("all paths must be directly under private runtime")
        if path.exists() or path.is_symlink():
            raise ValueError("output path exists already; refusing overwrite")
    if sock_path == marker_path:
        raise ValueError("socket and marker paths must differ")


def response(request):
    method = request.get("method")
    req_id = request.get("id")
    if method == "subscribe":
        return {
            "result": {
                "service": "server",
                "data": {
                    "apiVersion": API_VERSION,
                    "cliVersion": "2.1.0-mock",
                    "capabilities": [],
                },
            }
        }, False
    if method == "shell.ready":
        # A real shell.ready must carry the process ID.
        pid = request.get("params", {}).get("pid") if isinstance(request.get("params"), dict) else None
        if not isinstance(pid, (int, float)) or isinstance(pid, bool) or pid <= 0:
            return {"id": req_id, "error": "mock: shell.ready pid required"}, False
        return {"id": req_id, "result": {"accepted": True}}, True
    if method == "matugen.status":
        return {"id": req_id, "result": {"smartSupported": False}}, False
    return {"id": req_id, "error": "mock: unsupported method"}, False


def run(sock_path: Path, marker_path: Path, duration: float):
    check_private_paths(sock_path, marker_path)
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(str(sock_path))
    os.chmod(sock_path, 0o600)
    listener.listen(MAX_CLIENTS)
    listener.setblocking(False)
    selector = selectors.DefaultSelector()
    selector.register(listener, selectors.EVENT_READ)
    buffers = {}
    deadline = time.monotonic() + duration
    ready = False
    print("DMS_MOCK_BACKEND_PRIVATE_SOCKET_READY", flush=True)

    try:
        while not STOP and time.monotonic() < deadline and not ready:
            for key, _ in selector.select(timeout=0.2):
                if key.fileobj is listener:
                    connection, _ = listener.accept()
                    connection.setblocking(False)
                    selector.register(connection, selectors.EVENT_READ)
                    buffers[connection] = b""
                    continue

                connection = key.fileobj
                try:
                    data = connection.recv(8192)
                except (ConnectionResetError, BlockingIOError):
                    data = b""
                if not data:
                    selector.unregister(connection)
                    buffers.pop(connection, None)
                    connection.close()
                    continue

                buffer = buffers[connection] + data
                if len(buffer) > MAX_BUFFER:
                    selector.unregister(connection)
                    buffers.pop(connection, None)
                    connection.close()
                    continue

                while b"\n" in buffer:
                    raw, buffer = buffer.split(b"\n", 1)
                    if len(raw) > MAX_LINE:
                        continue
                    try:
                        request = json.loads(raw)
                    except (ValueError, UnicodeDecodeError):
                        continue
                    if not isinstance(request, dict):
                        continue
                    result, got_ready = response(request)
                    try:
                        connection.sendall((json.dumps(result, separators=(",", ":")) + "\n").encode())
                    except (BrokenPipeError, ConnectionResetError):
                        pass
                    if got_ready:
                        # Never write request content or auth data.
                        marker_path.write_text("DMS_MOCK_SHELL_READY_RECEIVED\n")
                        print("DMS_MOCK_SHELL_READY_RECEIVED", flush=True)
                        ready = True
                        break
                buffers[connection] = buffer
                if ready:
                    break
    finally:
        for connection in buffers:
            try:
                selector.unregister(connection)
                connection.close()
            except OSError:
                pass
        selector.unregister(listener)
        listener.close()
        selector.close()
        try:
            sock_path.unlink()
        except FileNotFoundError:
            pass
    return int(not ready)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, type=Path)
    parser.add_argument("--marker", required=True, type=Path)
    parser.add_argument("--duration", type=float, default=25.0)
    args = parser.parse_args()
    if not (0 < args.duration <= 30):
        parser.error("duration must be within 0..30 seconds")
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    try:
        return run(args.socket, args.marker, args.duration)
    except (OSError, ValueError) as exc:
        print(f"DMS_MOCK_BACKEND_BLOCKED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
