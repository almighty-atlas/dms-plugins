#!/usr/bin/env bash
# Offline, non-instantiating compilation of the real pinned DMS ShellCore
# QML dependency tree with the separate Screencopy-enabled argc=1 host.
# Does NOT start shell.qml, the full DMS frontend, or the DMS backend.
set -euo pipefail
umask 077

if [[ "$#" != 1 || "$1" != "--offline-probe" ]]; then
    echo "Usage: bash verify_dms_shellcore_type_tree.sh --offline-probe" >&2
    exit 2
fi

root=/tmp/dms-chatgpt-native-v02
dms_source="$root/dux-shell"
qml_root="$dms_source/quickshell"
dcommon="$dms_source/dux-qml-common"
build_dir=/tmp/dms-chatgpt-qs-v02-argc1/build-dms-screencopy-v01
binary="$build_dir/src/quickshell"
script_dir=$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd -P)
source_fixture="$script_dir/DmsShellCoreLoadProbe.qml"
dms_pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42
common_pin=0877466a25b8e191a865bf75d0e500de6351ae04

for tool in git timeout dbus-run-session grep mktemp cp; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "DMS_SHELLCORE_PROBE_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -L "$root" || -L "$dms_source" || -L "$qml_root" ||
      -L "$build_dir" || -L "$binary" || -L "$source_fixture" ||
      ! -O "$root" || ! -O "$build_dir" ||
      ! -f "$binary" || ! -x "$binary" || ! -O "$binary" ||
      ! -f "$source_fixture" || ! -f "$qml_root/ShellCore.qml" ||
      "$(readlink "$qml_root/DCommon" 2>/dev/null)" != "../dux-qml-common/DCommon" ]]; then
    echo "DMS_SHELLCORE_PROBE_BLOCKED: unsafe/missing isolated host or DMS source" >&2
    exit 1
fi
if [[ "$(git -C "$dms_source" rev-parse HEAD)" != "$dms_pin" ||
      "$(git -C "$dcommon" rev-parse HEAD)" != "$common_pin" ]]; then
    echo "DMS_SHELLCORE_PROBE_BLOCKED: pinned DMS/QML sources changed" >&2
    exit 1
fi
if ! grep -Eq '^SCREENCOPY:BOOL=(ON|TRUE)$' "$build_dir/CMakeCache.txt"; then
    echo "DMS_SHELLCORE_PROBE_BLOCKED: Screencopy disabled in new host" >&2
    exit 1
fi
if [[ -z "\${XDG_RUNTIME_DIR:-}" || "\${XDG_RUNTIME_DIR:-}" != /* ||
      ! -d "$XDG_RUNTIME_DIR" || -z "\${WAYLAND_DISPLAY:-}" ]]; then
    echo "DMS_SHELLCORE_PROBE_BLOCKED: no active Wayland session" >&2
    exit 1
fi
case "$WAYLAND_DISPLAY" in
    /*) socket="$WAYLAND_DISPLAY" ;;
    */*) echo "DMS_SHELLCORE_PROBE_BLOCKED: invalid Wayland socket name" >&2; exit 1 ;;
    *) socket="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
esac
[[ -S "$socket" ]] || {
    echo "DMS_SHELLCORE_PROBE_BLOCKED: Wayland socket absent" >&2
    exit 1
}
for key in QTWEBENGINE_DISABLE_SANDBOX QTWEBENGINE_CHROMIUM_FLAGS; do
    if [[ -n "$(printenv "$key" || true)" ]]; then
        echo "DMS_SHELLCORE_PROBE_BLOCKED: unsafe inherited QtWebEngine flags" >&2
        exit 1
    fi
done

# Only these two paths are created, inside already owned, temporary
# pinned-source and test directories. Both are removed on any exit.
private=$(mktemp -d "$root/shellcore-typecheck.XXXXXXXX")
fixture=
cleanup() {
    if [[ -n "$fixture" ]]; then rm -f -- "$fixture"; fi
    rm -rf -- "$private"
}
trap cleanup EXIT
for dir in home runtime config data cache state; do
    mkdir -m 700 -- "$private/$dir"
done
fixture=$(mktemp "$qml_root/DmsShellCoreLoadProbe_XXXXXXXX.qml")
cp -- "$source_fixture" "$fixture"

# Load the COMPLETE component type tree via Qt.createComponent, but do not
# instantiate ShellCore or any desktop bars or real DMS service objects.
status=0
cd -- "$build_dir"
/usr/bin/env -i \
    PATH="/usr/bin:/bin" LANG="C.UTF-8" \
    HOME="$private/home" XDG_RUNTIME_DIR="$private/runtime" \
    XDG_CONFIG_HOME="$private/config" XDG_DATA_HOME="$private/data" \
    XDG_CACHE_HOME="$private/cache" XDG_STATE_HOME="$private/state" \
    XDG_CURRENT_DESKTOP="DMS_SHELLCORE_ISOLATED_TYPECHECK" \
    XDG_SESSION_TYPE="wayland" WAYLAND_DISPLAY="$socket" \
    QT_QPA_PLATFORM="wayland" GSETTINGS_BACKEND="memory" \
    DMS_SOCKET="" NIRI_SOCKET="" \
    dbus-run-session -- \
    timeout --signal=TERM --kill-after=2s 12s \
    "$binary" --path "$fixture" > "$private/output.log" 2>&1 || status=$?

if [[ "$status" != 0 && "$status" != 124 ]] ||
   ! grep -Fq "DMS_SHELLCORE_QML_TYPE_TREE_READY" "$private/output.log" ||
   grep -Eq 'DMS_SHELLCORE_QML_TYPE_TREE_FAILED|ScreencopyView is not a type' "$private/output.log"; then
    echo "DMS_SHELLCORE_TYPE_TREE_FAILED: component load incomplete (exit $status)"
    grep -E 'ERROR|WARN|Error|error|module|Type |type|DMS_SHELLCORE' \
        "$private/output.log" | tail -n 45 || true
    exit 1
fi

echo "DMS_SHELLCORE_QML_TYPE_TREE_READY: YES"
echo "DMS_SHELLCORE_SOURCE_PINNED: YES"
echo "DMS_SHELLCORE_ONLY_COMPILED_NOT_INSTANTIATED"
echo "DMS_SHELLCORE_ISOLATED_XDG_AND_DBUS"
echo "DMS_SHELLCORE_NO_LIVE_DMS_CHANGES"
echo "DMS_SHELLCORE_NOTE: full DMS readiness/production startup still untested"
