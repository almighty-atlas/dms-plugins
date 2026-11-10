#!/usr/bin/env python3
"""Read-only CachyOS WebEngine preflight. No Qt process or browser data accessed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

PACKAGES = ("qt6-base", "qt6-declarative", "qt6-webengine", "quickshell")
TOOLS = ("cmake", "c++")


def package_version(name):
    try:
        proc = subprocess.run(["pacman", "-Q", name], capture_output=True,
                              text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    fields = proc.stdout.strip().split()
    return fields[1] if proc.returncode == 0 and len(fields) == 2 and fields[0] == name else None


def sandbox_disabled(env):
    value = env.get("QTWEBENGINE_DISABLE_SANDBOX", "").strip().lower()
    flags = env.get("QTWEBENGINE_CHROMIUM_FLAGS", "").split()
    return value not in ("", "0", "false", "no") or any(
        flag == "--no-sandbox" or flag.startswith("--no-sandbox=") for flag in flags
    )


def snapshot(env=None, versions=None, which=None, process_exists=None):
    env = os.environ if env is None else env
    versions = package_version if versions is None else versions
    which = shutil.which if which is None else which
    process_exists = (
        lambda: Path("/usr/lib/qt6/QtWebEngineProcess").is_file()
    ) if process_exists is None else process_exists
    packages = {name: versions(name) for name in PACKAGES}
    tools = {name: bool(which(name)) for name in TOOLS}
    wayland = bool(env.get("WAYLAND_DISPLAY"))
    engine = bool(process_exists())
    unsafe = sandbox_disabled(env)
    ready = all(packages[p] for p in PACKAGES[:3]) and all(tools.values()) and wayland and engine
    return {
        "schema": "dms-chatgpt-webengine-preflight-v1",
        "packages": packages,
        "tools": tools,
        "wayland_available": wayland,
        "webengine_process_installed": engine,
        "sandbox_disabled_in_environment": unsafe,
        "standalone_prerequisites": "BLOCKED_UNSAFE" if unsafe else
            "READY_TO_PROBE" if ready else "MISSING_DEPENDENCIES",
        "quickshell_embedded_webengine": "UNVERIFIED",
        "note": "Standalone readiness does not prove initialization inside DMS"
    }


def main():
    result = snapshot()
    print(json.dumps(result, indent=2, sort_keys=True))
    state = result["standalone_prerequisites"]
    return 0 if state == "READY_TO_PROBE" else 2 if state == "BLOCKED_UNSAFE" else 1


if __name__ == "__main__":
    sys.exit(main())
