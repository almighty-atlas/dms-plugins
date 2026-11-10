#!/usr/bin/env bash
# Inner worker: headless Weston -> nested Niri -> full DMS QML frontend.
# ONLY run by run_dms_headless_niri.sh with env -i / private XDG/DBus.
# The host desktop Wayland socket is NEVER forwarded.
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
      -n "${NIRI_BACKEND:-}" ||
      "${XDG_RUNTIME_DIR:-}" != "$private/runtime" ||
      "${DMS_SOCKET-something}" != "" ||
      "${NOTIFY_SOCKET-something}" != "" ||
      "${WAYLAND_DISPLAY:-}" != "" ||
      "${NIRI_SOCKET-something}" != "" ]]; then
    echo "DMS_HEADLESS_INNER_BLOCKED: unsafe environment or sources" >&2
    exit 1
fi
if ! command -v niri >/dev/null 2>&1 || ! command -v weston >/dev/null 2>&1 || ! command -v timeout >/dev/null 2>&1; then
    echo "DMS_HEADLESS_INNER_BLOCKED: niri/weston/timeout missing" >&2
    exit 1
fi

weston_pid=
niri_pid=
cleanup_inner() {
    if [[ -n "$niri_pid" ]]; then
        kill -TERM "$niri_pid" 2>/dev/null || true
        wait "$niri_pid" 2>/dev/null || true
    fi
    if [[ -n "$weston_pid" ]]; then
        kill -TERM "$weston_pid" 2>/dev/null || true
        wait "$weston_pid" 2>/dev/null || true
    fi
}
trap cleanup_inner EXIT

# Niri v26.04 does NOT support NIRI_BACKEND=headless, despite references
# to that flag in unrelated branches/forks. It chooses Winit when a valid
# parent Wayland display exists. Create that display in a fully private
# headless Weston first; no physical KMS/TTY/real Niri is accessed.
weston_name=weston-dms-sandbox
weston_socket="$private/runtime/$weston_name"
weston --backend=headless --renderer=gl --no-config --shell=kiosk \
      --socket="$weston_name" --width=1280 --height=800 --idle-time=0 \
      > "$private/weston.log" 2>&1 &
weston_pid=$!
for ((i=0; i<50; i++)); do
    [[ -S "$weston_socket" ]] && break
    if ! kill -0 "$weston_pid" 2>/dev/null; then break; fi
    sleep 0.2
done
if [[ ! -S "$weston_socket" ]]; then
    echo "DMS_HEADLESS_WESTON_START_FAILED: no private parent Wayland socket" >&2
    grep -Ei 'error|fail|fatal|headless|backend|renderer' "$private/weston.log" | tail -n 25 || true
    exit 1
fi
echo "DMS_HEADLESS_WESTON_PRIVATE_SOCKET_READY"

# No --session: avoids importing state into the real session manager.
# The only parent WAYLAND_DISPLAY is the just-created private Weston socket.
WAYLAND_DISPLAY="$weston_name" niri --config "$private/config/niri.kdl" \
      > "$private/niri.log" 2>&1 &
niri_pid=$!
socket=
for ((i=0; i<60; i++)); do
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
echo "DMS_HEADLESS_NIRI_NESTED_WITHIN_WESTON"
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
