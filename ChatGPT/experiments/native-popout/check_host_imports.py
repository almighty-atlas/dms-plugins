#!/usr/bin/env python3
"""Read-only DMS QML import vs isolated Quickshell CMake flag audit.

A source-wide import check is conservative; it is NOT a QML runtime test.
No shell, browser, daemon or plugin process is started.
"""
import json
from collections import defaultdict
from pathlib import Path
import re
import sys

DMS_ROOT = Path("/tmp/dms-chatgpt-native-v02/dux-shell/quickshell")
CMAKE_CACHE = Path("/tmp/dms-chatgpt-qs-v02-argc1/build-layer/CMakeCache.txt")
IMPORT_RE = re.compile(r"^\s*import\s+(Quickshell(?:\.[a-zA-Z_][a-zA-Z_0-9]*)*)\b", re.M)
BOOL_RE = re.compile(r"^([A-Z][A-Z0-9_]*):BOOL=(ON|OFF|TRUE|FALSE|1|0)$", re.M)

# Feature names correspond to upstream Quickshell CMakeLists.txt. Modules
# not in this mapping are reported as UNKNOWN, never silently considered ready.
FEATURES = {
    "Quickshell.I3": "I3",
    "Quickshell.Hyprland": "HYPRLAND",
    "Quickshell.Wayland": "WAYLAND",
    "Quickshell.Wayland._WlrLayerShell": "WAYLAND_WLR_LAYERSHELL",
    "Quickshell.Wayland._SessionLock": "WAYLAND_SESSION_LOCK",
    "Quickshell.Wayland._Screencopy": "SCREENCOPY",
    "Quickshell.Wayland._ToplevelManagement": "WAYLAND_TOPLEVEL_MANAGEMENT",
    "Quickshell.Services.SystemTray": "SERVICE_STATUS_NOTIFIER",
    "Quickshell.Services.Pipewire": "SERVICE_PIPEWIRE",
    "Quickshell.Services.Mpris": "SERVICE_MPRIS",
    "Quickshell.Services.Polkit": "SERVICE_POLKIT",
    "Quickshell.Services.Pam": "SERVICE_PAM",
    "Quickshell.Services.Greetd": "SERVICE_GREETD",
    "Quickshell.Services.UPower": "SERVICE_UPOWER",
    "Quickshell.Services.Notifications": "SERVICE_NOTIFICATIONS",
    "Quickshell.Bluetooth": "BLUETOOTH",
    "Quickshell.Network": "NETWORK",
}
CORE = {
    "Quickshell", "Quickshell.Io", "Quickshell.Widgets",
    "Quickshell.Services", "Quickshell.WindowManager",
}


def imports_from_text(text):
    return set(IMPORT_RE.findall(text))


def read_cmake_bool(text):
    return {
        name: value in {"ON", "TRUE", "1"}
        for name, value in BOOL_RE.findall(text)
    }


def audit(source, cache):
    imports = defaultdict(list)
    for qml in sorted(source.rglob("*.qml")):
        # Never follow QML-file symlinks outside the checked-out DMS source.
        if qml.is_symlink():
            continue
        for uri in imports_from_text(qml.read_text(encoding="utf-8")):
            imports[uri].append(str(qml.relative_to(source)))

    flags = read_cmake_bool(cache.read_text(encoding="utf-8"))
    missing, unknown, enabled = [], [], []
    for uri in sorted(imports):
        key = FEATURES.get(uri)
        usage = len(imports[uri])
        row = {"module": uri, "qml_files": usage}
        if uri in CORE:
            enabled.append({**row, "feature": "always-built"})
        elif key is None:
            unknown.append(row)
        elif key not in flags:
            unknown.append({**row, "feature": key, "note": "flag not in cache"})
        elif not flags[key]:
            missing.append({**row, "feature": key})
        else:
            enabled.append({**row, "feature": key})

    return {
        "status": "DISABLED_MODULES_FOUND" if missing else
                  ("UNKNOWN_MODULES" if unknown else "FLAGS_COMPATIBLE_UNVERIFIED"),
        "scope": "all DMS QML files; includes dormant features",
        "runtime_compatibility": "NOT_TESTED",
        "qml_files_scanned": sum(1 for x in source.rglob("*.qml") if not x.is_symlink()),
        "enabled_imports": enabled,
        "disabled_imports": missing,
        "unknown_imports": unknown,
    }


def main():
    if not DMS_ROOT.is_dir() or not CMAKE_CACHE.is_file():
        print("DMS_HOST_IMPORT_AUDIT_FAILED: missing prepared /tmp source or CMake cache", file=sys.stderr)
        return 1
    report = audit(DMS_ROOT, CMAKE_CACHE)
    print("DMS_HOST_IMPORT_AUDIT")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
