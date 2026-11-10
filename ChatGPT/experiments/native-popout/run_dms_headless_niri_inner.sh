#!/usr/bin/env bash
# Inner worker. ONLY run by run_dms_headless_niri.sh with an env -i private
# XDG_RUNTIME_DIR and a new session D-Bus. Never use the live Wayland socket.
set -euo pipefail
umask 077

if [[ "$#" != 4 || "$1" != "--inner" ]]; then
    echo "DMS_HEADLESS_INNER_BLOCKED: controlled invocation required" >&2
    exit 2
fi
private="$2"
binary="$3"
fixture="$4"
if [[ -L "$private" || -L "$fixture" || ! -d "$private" ||
      ! -O "$private" || ! -f "$fixture" || ! -O "$fixture" ||
      ! -f "$binary" || ! -O "$binary" || ! -x "$binary" ||
      "${NIRI_BACKEND:-}" != "headless" ||
      "${XDG_RUNTIME_DIR:-}" != "$private/runtime" ||
      "${DMS_SOCKET:-something}" != "" ||
      "${NOTIFY_SOCKET:-something}" != "" ||
      "${WAYLAND_DISPLAY:-}" != "" ||
      "${NIRI_SOCKET:-something}" != "" ]]; then
    echo "DMS_HEADLESS_INNER_BLOCKED: unsafe environment or sources" >&2
    exit 1
fi
if ! command -v niri >/dev/null 2>&1 || ! command -v timeout >/dev/null 2>&1; then
    echo "DMS_HEADLESS_INNER_BLOCKED: niri/timeout missing" >&2
    exit 1
fi

niri_pid=
cleanup_inner() {
    if [[ -n "$niri_pid" ]]; then
        kill -TERM "$niri_pid" 2>/dev/null || true
        wait "$niri_pid" 2>/dev/null || true
    fi
}
trap cleanup_inner EXIT

# Not --session: that flag imports environment into the real user manager.
# Headless backend uses private runtime sockets and no physical display.
niri --config "$private/config/niri.kdl" > "$private/niri.log" 2>&1 &
niri_pid=$!
socket=
for ((i=0; i<65; i++)); do
    socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' -print -quit)
    [[ -n "$socket" ]] && break
    if ! kill -0 "$niri_pid" 2>/dev/null; then break; fi
    sleep 0.2
done
if [[ -z "$socket" || ! -S "$socket" || "$socket" != "$private/runtime/"* ]]; then
    echo "DMS_HEADLESS_NIRI_START_FAILED: no private Wayland socket" >&2
    grep -Ei 'error|fail|fatal|headless|backend|config' "$private/niri.log" | tail -n 20 || true
    exit 1
fi
nested_niri=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'niri.*.sock' -print -quit)
if [[ -n "$nested_niri" && "$nested_niri" != "$private/runtime/"* ]]; then
    echo "DMS_HEADLESS_INNER_BLOCKED: Niri IPC escaped private runtime" >&2
    exit 1
fi
echo "DMS_HEADLESS_NIRI_PRIVATE_SOCKET_READY"
echo "DMS_HEADLESS_NIRI_NO_SESSION_IMPORT"
status=0

# Reuse the private D-Bus session and all private XDG paths, but expose
# ONLY this nested Niri's Wayland/IPC sockets to the test frontend.
WAYLAND_DISPLAY="$socket" NIRI_SOCKET="$nested_niri" \
    timeout --signal=TERM --kill-after=3s 16s \
    "$binary" --path "$fixture" > "$private/quickshell.log" 2>&1 || status=$?

# Static start-success markers are instrumentation in the pinned QML copy,
# not a DMS backend readiness handshake (no DMS_SOCKET/NOTIFY_SOCKET).
if [[ "$status" != 0 && "$status" != 124 ]] ||
   ! grep -Fq "DMS_HEADLESS_ENTRY_INSTANTIATED" "$private/quickshell.log" ||
   ! grep -Fq "DMS_HEADLESS_DMSSHELL_LOADED" "$private/quickshell.log" ||
   grep -Eq "Type .* unavailable|ScreencopyView is not a type|module .* is not installed|DMS_HEADLESS_DMSSHELL_FAILED" "$private/quickshell.log"; then
    echo "DMS_HEADLESS_FULL_UI_FAILED: startup markers missing or QML type unavailable (exit $status)"
    grep -Ei 'error|fail|fatal|warn|type|module|DMS_HEADLESS|configuration loaded' \
        "$private/quickshell.log" | tail -n 55 || true
    exit 1
fi
echo "DMS_HEADLESS_ENTRY_INSTANTIATED: YES"
echo "DMS_HEADLESS_DMSSHELL_LOADED: YES"
echo "DMS_HEADLESS_FULL_UI_TYPE_ERRORS: NONE_DETECTED"
echo "DMS_HEADLESS_BACKEND_READY: NOT_TESTED (private DMS_SOCKET empty)"
echo "DMS_HEADLESS_NO_LIVE_NIRI_OR_DMS_CHANGES"
