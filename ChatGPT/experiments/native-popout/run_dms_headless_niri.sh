#!/usr/bin/env bash
# Bounded full DMS QML instantiation in a SECOND headless Niri compositor.
# No dms backend, login, real Niri socket, systemd changes or package writes.
set -euo pipefail
umask 077

if [[ "$#" != 1 || "$1" != "--headless-probe" ]]; then
    echo "Usage: bash run_dms_headless_niri.sh --headless-probe" >&2
    exit 2
fi

root=/tmp/dms-chatgpt-native-v02
dms_source="$root/dux-shell"
qml_root="$dms_source/quickshell"
dcommon="$dms_source/dux-qml-common"
build_dir=/tmp/dms-chatgpt-qs-v02-argc1/build-dms-screencopy-v01
binary="$build_dir/src/quickshell"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
inner="$script_dir/run_dms_headless_niri_inner.sh"
dms_pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42
common_pin=0877466a25b8e191a865bf75d0e500de6351ae04

for tool in niri git python3 timeout dbus-run-session mktemp grep; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "DMS_HEADLESS_BLOCKED: missing $tool" >&2
        exit 1
    fi
done
if [[ -L "$root" || -L "$dms_source" || -L "$build_dir" ||
      -L "$binary" || -L "$inner" ||
      ! -d "$dms_source/.git" || ! -d "$dcommon" ||
      ! -f "$qml_root/shell.qml" || ! -f "$inner" ||
      ! -O "$root" || ! -O "$build_dir" ||
      ! -f "$binary" || ! -x "$binary" || ! -O "$binary" ||
      "$(readlink "$qml_root/DCommon" 2>/dev/null)" != "../dux-qml-common/DCommon" ]]; then
    echo "DMS_HEADLESS_BLOCKED: private DMS or Quickshell sources not trusted" >&2
    exit 1
fi
if [[ "$(git -C "$dms_source" rev-parse HEAD)" != "$dms_pin" ||
      "$(git -C "$dcommon" rev-parse HEAD)" != "$common_pin" ]] ||
   ! git -C "$dms_source" diff --quiet; then
    echo "DMS_HEADLESS_BLOCKED: pinned DMS/DCommon sources changed" >&2
    exit 1
fi
for flag in WAYLAND WAYLAND_WLR_LAYERSHELL SCREENCOPY SCREENCOPY_ICC SCREENCOPY_WLR SCREENCOPY_HYPRLAND_TOPLEVEL; do
    if ! grep -Eq "^$flag:BOOL=(ON|TRUE)$" "$build_dir/CMakeCache.txt"; then
        echo "DMS_HEADLESS_BLOCKED: required Quickshell feature $flag disabled" >&2
        exit 1
    fi
done

private=$(mktemp -d "$root/dms-headless-niri.XXXXXXXX")
fixture=
cleanup() {
    [[ -z "$fixture" ]] || rm -f -- "$fixture"
    rm -rf -- "$private"
}
trap cleanup EXIT
for dir in home runtime config data cache state; do
    mkdir -m 700 -- "$private/$dir"
done
# Niri MUST use this explicit private config. Empty config intentionally
# contains no spawn-at-startup, binds, environment imports or user rules.
printf '%s\n' '// Private headless Niri for an isolated, bounded DMS test.' > "$private/config/niri.kdl"
fixture=$(mktemp "$qml_root/DmsHeadlessShell_XXXXXXXX.qml")

# Instrument ONLY an untracked, temporary copy of the exact pinned shell.qml
# with two logs; preserve source text and original async DMS loader behavior.
python3 - "$qml_root/shell.qml" "$fixture" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
a = "    Component.onCompleted: {\n        DC.Style.theme = Theme;"
b = "    Component.onCompleted: {\n        console.log(\"DMS_HEADLESS_ENTRY_INSTANTIATED\");\n        DC.Style.theme = Theme;"
c = '    Loader {\n        id: dmsShellLoader\n        asynchronous: true\n    }'
d = ('    Loader {\n        id: dmsShellLoader\n        asynchronous: true\n'
     '        onLoaded: console.log("DMS_HEADLESS_DMSSHELL_LOADED")\n'
     '        onStatusChanged: {\n'
     '            if (status === Loader.Error)\n'
     '                console.error("DMS_HEADLESS_DMSSHELL_FAILED")\n'
     '        }\n    }')
if source.count(a) != 1 or source.count(c) != 1:
    raise SystemExit("DMS_HEADLESS_BLOCKED: unexpected pinned shell.qml loader")
Path(sys.argv[2]).write_text(source.replace(a, b).replace(c, d), encoding="utf-8")
PY

echo "DMS_HEADLESS_NIRI_PROBE: separate headless compositor, no --session"
echo "DMS_HEADLESS_DMS_BACKEND: DISCONNECTED_BY_DESIGN"
echo "DMS_HEADLESS_LIVE_NIRI_SOCKET: NOT_FORWARDED"
# env -i prevents inherited session/process IPC, graphics overrides,
# user config, or leaking the current DISPLAY/NIRI_SOCKET to this test.
status=0
/usr/bin/env -i \
    PATH="/usr/bin:/bin" LANG="C.UTF-8" \
    HOME="$private/home" XDG_RUNTIME_DIR="$private/runtime" \
    XDG_CONFIG_HOME="$private/config" XDG_DATA_HOME="$private/data" \
    XDG_CACHE_HOME="$private/cache" XDG_STATE_HOME="$private/state" \
    XDG_CURRENT_DESKTOP="niri-headless-test" XDG_SESSION_TYPE="wayland" \
    NIRI_BACKEND="headless" NIRI_CONFIG="$private/config/niri.kdl" \
    WAYLAND_DISPLAY="" NIRI_SOCKET="" DMS_SOCKET="" NOTIFY_SOCKET="" \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$private/runtime/no-system-bus" \
    QT_QPA_PLATFORM="wayland" GSETTINGS_BACKEND="memory" \
    DMS_DISABLE_HOT_RELOAD="1" \
    dbus-run-session -- \
    timeout --signal=TERM --kill-after=5s 38s \
    /usr/bin/bash "$inner" --inner "$private" "$binary" "$fixture" || status=$?

if [[ "$status" != 0 ]]; then
    echo "DMS_HEADLESS_PROBE_FAILED: inner process exited $status" >&2
    exit 1
fi
echo "DMS_HEADLESS_TEST_TERMINATED_AND_CLEANED"
