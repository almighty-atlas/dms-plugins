"""Private, fixed-path plugin state. Never read browser authentication data."""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import tempfile
import time


class Failure(Exception):
    pass


def data_dir():
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    if not base.is_absolute():
        raise Failure("XDG_DATA_HOME muss ein absoluter Pfad sein.")
    path = base / "dms-chatgpt"
    private_dir(path)
    return path


def private_dir(path):
    if path.is_symlink():
        raise Failure("Plugin-Datenpfad darf kein Symlink sein.")
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if path.stat().st_uid != os.getuid():
        raise Failure("Plugin-Datenverzeichnis gehört einem anderen Benutzer.")
    path.chmod(0o700)


def atomic_write(path, text):
    if path.is_symlink():
        raise Failure("Verwaltete Datei darf kein Symlink sein.")
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    fd, name = tempfile.mkstemp(prefix=".dms-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(text)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextmanager
def locked(timeout=25):
    # Never unlink a lock file: another launcher may already be waiting on its inode.
    fd = os.open(data_dir() / "launcher.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise Failure("Ein anderer ChatGPT-Start dauert noch an. Bitte erneut versuchen.")
                time.sleep(0.1)
        yield
    finally:
        os.close(fd)


def read_json(path):
    if path.is_symlink():
        raise Failure("Verwaltete Datei darf kein Symlink sein.")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
