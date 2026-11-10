#!/usr/bin/env bash
# Isolated Wayland/QML ScreencopyView type smoke for the NEW build only.
# The production DMS process, user plugins, and auth cookies are not touched.
set -euo pipefail
umask 077

if [[ "$#" != 1 || "$1" != "--offline-probe" ]]; then
    echo "Usage: bash verify_quickshell_screencopy.sh --offline-probe" >&2
    exit 2
fi

root=/tmp/dms-chatgpt-qs-v02-argc1
source_dir="$root/source"
build_dir="$root/build-dms-screencopy-v01"
binary="$build_dir/src/quickshell"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
fixture="$script_dir/ScreencopyViewImportProbe.qml"
pin=9b0f339b19057f4731bf3b48293307d7ef241671

for tool in timeout dbus-run-session grep git ldd mktemp; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "DMS_SCREENCOPY_PROBE_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -L "$root" || -L "$build_dir" || -L "$binary" ||
      ! -O "$root" || ! -O "$build_dir" ||
      ! -f "$binary" || ! -O "$binary" || ! -x "$binary" ||
      -L "$fixture" || ! -f "$fixture" ]] ||
   [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$pin" ]]; then
    echo "DMS_SCREENCOPY_PROBE_BLOCKED: unknown or unsafe build/fixture" >&2
    exit 1
fi
for flag in WAYLAND SCREENCOPY SCREENCOPY_ICC SCREENCOPY_WLR SCREENCOPY_HYPRLAND_TOPLEVEL; do
    grep -Eq "^$flag:BOOL=(ON|TRUE)$" "$build_dir/CMakeCache.txt" || {
        echo "DMS_SCREENCOPY_PROBE_BLOCKED: required $flag was not enabled" >&2
        exit 1
    }
done
if ldd "$binary" | grep -Fq "not found"; then
    echo "DMS_SCREENCOPY_PROBE_BLOCKED: missing shared library" >&2
    exit 1
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" || "${XDG_RUNTIME_DIR:-}" != /* ||
      ! -d "$XDG_RUNTIME_DIR" || -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "DMS_SCREENCOPY_PROBE_BLOCKED: Wayland session unavailable" >&2
    exit 1
fi
case "$WAYLAND_DISPLAY" in
    /*) socket="$WAYLAND_DISPLAY" ;;
    */*) echo "DMS_SCREENCOPY_PROBE_BLOCKED: unexpected Wayland socket" >&2; exit 1 ;;
    *) socket="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
esac
if [[ ! -S "$socket" ]]; then
    echo "DMS_SCREENCOPY_PROBE_BLOCKED: no Wayland socket" >&2
    exit 1
fi
for key in QTWEBENGINE_DISABLE_SANDBOX QTWEBENGINE_CHROMIUM_FLAGS; do
    if [[ -n "$(printenv "$key" || true)" ]]; then
        echo "DMS_SCREENCOPY_PROBE_BLOCKED: unsafe inherited WebEngine flag" >&2
        exit 1
    fi
done

private=$(mktemp -d -- "$root/screencopy-verify.XXXXXXXX")
trap 'rm -rf -- "$private"' EXIT
for dir in home runtime config data cache state; do
    mkdir -m 700 "$private/$dir"
done
# Some static modules may consult the current working directory.
# This is an owner-controlled build tree, never an arbitrary CWD.
cd -- "$build_dir"
status=0
/usr/bin/env -i \
    PATH="/usr/bin:/bin" LANG="C.UTF-8" \
    HOME="$private/home" XDG_RUNTIME_DIR="$private/runtime" \
    XDG_CONFIG_HOME="$private/config" XDG_DATA_HOME="$private/data" \
    XDG_CACHE_HOME="$private/cache" XDG_STATE_HOME="$private/state" \
    XDG_CURRENT_DESKTOP="DMS_SCREENCOPY_OFFLINE_PROBE" \
    XDG_SESSION_TYPE="wayland" WAYLAND_DISPLAY="$socket" \
    QT_QPA_PLATFORM="wayland" GSETTINGS_BACKEND="memory" \
    DMS_SOCKET="" NIRI_SOCKET="" \
    dbus-run-session -- \
    timeout --signal=TERM --kill-after=2s 8s \
    "$binary" --path "$fixture" >"$private/output.log" 2>&1 || status=$?

if [[ "$status" != 0 && "$status" != 124 ]] ||
   ! grep -Fq "DMS_SCREENCOPY_QML_READY" "$private/output.log" ||
   grep -Eq 'ScreencopyView is not a type|DMS_SCREENCOPY_QML_INSTANTIATION_FAILED' "$private/output.log"; then
    echo "DMS_SCREENCOPY_RUNTIME_FAILED: QML type failed to instantiate (exit $status)"
    grep -E 'ERR|Error|error|WARN|Warning|ScreencopyView|DMS_SCREENCOPY' "$private/output.log" | tail -n 35 || true
    exit 1
fi
echo "DMS_SCREENCOPY_CMAKE_FLAGS: ENABLED"
echo "DMS_SCREENCOPY_QML_READY: YES"
echo "DMS_SCREENCOPY_ISOLATED_OFFLINE_ONLY"
echo "DMS_SCREENCOPY_NO_LIVE_DMS_CHANGES"
echo "DMS_SCREENCOPY_NOTE: full production DMS has not yet been launched with this build"
