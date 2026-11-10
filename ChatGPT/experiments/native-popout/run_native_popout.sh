#!/usr/bin/env bash
# OFFLINE native DMS PluginPopout probe in a private process and XDG state.
# No browser login, service connection, package installation or DMS restart.
set -euo pipefail
umask 077

root=/tmp/dms-chatgpt-native-v02
qml_root="$root/dux-shell/quickshell"
harness="$qml_root/ChatGPTNativeHarness.qml"
binary=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell
source_dir=/tmp/dms-chatgpt-qs-v02-argc1/source

if [[ -L "$root" || -L "$qml_root" || -L "$harness" ||
      ! -f "$harness" || ! -x "$binary" || ! -O "$root" ]] ||
   [[ ! -d "$source_dir/.git" || ! -d "$root/dux-shell/.git" ]]; then
    echo "DMS_NATIVE_RUN_BLOCKED: missing/unsafe isolated sources or binary" >&2
    exit 1
fi
if [[ "$(git -C "$root/dux-shell" rev-parse HEAD)" != "e46ccbc1d58930d6a189cd1c90b276db2d64bf42" ||
      "$(git -C "$source_dir" rev-parse HEAD)" != "9b0f339b19057f4731bf3b48293307d7ef241671" ]]; then
    echo "DMS_NATIVE_RUN_BLOCKED: unreviewed upstream revision" >&2
    exit 1
fi
# Do not silently use a live DMS configuration with unknown edits.
untracked="$(git -C "$root/dux-shell" status --porcelain |
  grep -v '^?? quickshell/ChatGPTNativeProbe/' |
  grep -v '^?? quickshell/ChatGPTNativeHarness.qml' || true)"
if [[ -n "$untracked" ]]; then
    echo "DMS_NATIVE_RUN_BLOCKED: unexpected changes to DMS source" >&2
    exit 1
fi

original_runtime="$XDG_RUNTIME_DIR"
wayland_name="$WAYLAND_DISPLAY"
[[ "$original_runtime" == /* && -d "$original_runtime" ]] || {
    echo "DMS_NATIVE_RUN_BLOCKED: original XDG_RUNTIME_DIR missing" >&2
    exit 1
}
if [[ "$wayland_name" == /* ]]; then
    socket="$wayland_name"
else
    [[ "$wayland_name" != */* ]] || exit 1
    socket="$original_runtime/$wayland_name"
fi
[[ -S "$socket" ]] || {
    echo "DMS_NATIVE_RUN_BLOCKED: Wayland compositor socket missing" >&2
    exit 1
}
for cmd in dbus-run-session timeout; do
    command -v "$cmd" >/dev/null || {
        echo "DMS_NATIVE_RUN_BLOCKED: $cmd unavailable" >&2
        exit 1
    }
done
for key in QTWEBENGINE_DISABLE_SANDBOX QTWEBENGINE_CHROMIUM_FLAGS; do
    if [[ -n "$(printenv "$key" || true)" ]]; then
        echo "DMS_NATIVE_RUN_BLOCKED: inherited unsafe WebEngine flag $key" >&2
        exit 1
    fi
done
for dir in home config data cache state runtime; do
    [[ ! -L "$root/$dir" ]] || {
        echo "DMS_NATIVE_RUN_BLOCKED: symlinked private directory" >&2
        exit 1
    }
    mkdir -p -m 700 "$root/$dir"
    chmod 700 "$root/$dir"
done

echo "DMS_NATIVE_TEST_STARTED: real PluginPopout; offline HTML only"
echo "DMS_NATIVE_ISOLATION: private HOME, XDG and session DBus; DMS_SOCKET and NIRI_SOCKET blank"
echo "DMS_NATIVE_TEST_INSTRUCTIONS: click pill, type test, dismiss, reopen"
echo "DMS_NATIVE_AUTO_STOP: 60 seconds"
# The compositor socket is deliberately shared so Niri can show the test
# window; other user runtime sockets remain inaccessible via the private
# XDG_RUNTIME_DIR. This is not a kernel/filesystem security sandbox.
exec /usr/bin/env -i \
    PATH="/usr/bin:/bin" \
    HOME="$root/home" \
    LANG="C.UTF-8" \
    XDG_RUNTIME_DIR="$root/runtime" \
    XDG_CONFIG_HOME="$root/config" \
    XDG_DATA_HOME="$root/data" \
    XDG_CACHE_HOME="$root/cache" \
    XDG_STATE_HOME="$root/state" \
    XDG_CURRENT_DESKTOP="DMS_NATIVE_OFFLINE_PROBE" \
    XDG_SESSION_TYPE="wayland" \
    WAYLAND_DISPLAY="$socket" \
    QT_QPA_PLATFORM="wayland" \
    GSETTINGS_BACKEND="memory" \
    DMS_SOCKET="" \
    NIRI_SOCKET="" \
    dbus-run-session -- \
    timeout --signal=TERM --kill-after=3s 60s \
    "$binary" --path "$harness"
