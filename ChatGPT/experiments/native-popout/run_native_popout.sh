#!/usr/bin/env bash
# Native DMS PluginPopout probe (offline default, public site explicit).
# No credential interaction, package installation, DMS connection or restart.
set -euo pipefail
umask 077

online=0
persistent=0
auth=0
relocation=0
staged=0
screencopy_host=0
duration=60s
if [[ "$#" == 0 ]]; then
    : # default: local HTML only
elif [[ "$#" == 1 && "$1" == "--public-chatgpt" ]]; then
    online=1
elif [[ "$#" == 1 && "$1" == "--persistent-chatgpt" ]]; then
    online=1
    persistent=1
elif [[ "$#" == 1 && "$1" == "--auth-chatgpt" ]]; then
    online=1
    auth=1
    duration=300s
elif [[ "$#" == 1 && "$1" == "--relocation-check" ]]; then
    relocation=1
elif [[ "$#" == 1 && "$1" == "--staged-host-check" ]]; then
    staged=1
elif [[ "$#" == 1 && "$1" == "--screencopy-host-check" ]]; then
    screencopy_host=1
else
    echo "Usage: run_native_popout.sh [--public-chatgpt|--persistent-chatgpt|--auth-chatgpt|--relocation-check|--staged-host-check|--screencopy-host-check]" >&2
    exit 2
fi

root=/tmp/dms-chatgpt-native-v02
qml_root="$root/dux-shell/quickshell"
harness="$qml_root/ChatGPTNativeHarness.qml"
binary=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell
source_dir=/tmp/dms-chatgpt-qs-v02-argc1/source

# The successful full-DMS Screencopy build is selected only by an
# explicit offline-only mode. The original host and all login modes
# retain their exact previous binaries and profiles.
if [[ "$screencopy_host" == 1 ]]; then
    screencopy_build=/tmp/dms-chatgpt-qs-v02-argc1/build-dms-screencopy-v01
    binary="$screencopy_build/src/quickshell"
    if [[ -L "$screencopy_build" || -L "$binary" ||
          ! -d "$screencopy_build" || ! -O "$screencopy_build" ||
          ! -f "$binary" || ! -O "$binary" || ! -x "$binary" ]]; then
        echo "DMS_NATIVE_SCREENCOPY_HOST_BLOCKED: new build missing or untrusted" >&2
        exit 1
    fi
    for flag in WAYLAND SCREENCOPY SCREENCOPY_ICC SCREENCOPY_WLR SCREENCOPY_HYPRLAND_TOPLEVEL; do
        if ! grep -Eq "^$flag:BOOL=(ON|TRUE)$" "$screencopy_build/CMakeCache.txt"; then
            echo "DMS_NATIVE_SCREENCOPY_HOST_BLOCKED: $flag not enabled" >&2
            exit 1
        fi
    done
    if ldd "$binary" | grep -Fq "not found"; then
        echo "DMS_NATIVE_SCREENCOPY_HOST_BLOCKED: missing linked library" >&2
        exit 1
    fi
    # The build-tree binary may contain empty RUNPATH entries. Do not
    # execute it from an arbitrary, possibly untrusted working directory.
    cd -- "$screencopy_build"
    echo "DMS_NATIVE_SCREENCOPY_HOST: $binary"
    echo "DMS_NATIVE_SCREENCOPY_HOST_OFFLINE_ONLY"
    echo "DMS_NATIVE_SCREENCOPY_HOST_NO_SERVICE_CHANGE"
fi

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

common_dir="$root/dux-shell/dux-qml-common"
if [[ ! -d "$common_dir/.git" && ! -f "$common_dir/.git" ]] ||
   [[ ! -d "$qml_root/DCommon/Widgets" ]] ||
   [[ "$(readlink "$qml_root/DCommon" 2>/dev/null)" != "../dux-qml-common/DCommon" ]]; then
    echo "DMS_NATIVE_RUN_BLOCKED: DCommon submodule missing; rerun prepare_sandbox.sh" >&2
    exit 1
fi
if [[ "$(git -C "$common_dir" rev-parse HEAD)" != "0877466a25b8e191a865bf75d0e500de6351ae04" ]]; then
    echo "DMS_NATIVE_RUN_BLOCKED: unreviewed DCommon submodule revision" >&2
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
# Auth data lives in a separate user-owned 0700 directory so it survives
# restarts and /tmp cleanup; the other three modes still use /tmp only.
profile_root="$root"
if [[ "$auth" == 1 ]]; then
    if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
        echo "DMS_NATIVE_RUN_BLOCKED: unsafe auth HOME" >&2
        exit 1
    fi
    profile_root="$HOME/.local/share/dms-chatgpt-native-auth-probe"
    if [[ -L "$profile_root" || ( -e "$profile_root" && ! -O "$profile_root" ) ]]; then
        echo "DMS_NATIVE_RUN_BLOCKED: unsafe auth profile root" >&2
        exit 1
    fi
    mkdir -p -m 700 "$profile_root"
    chmod 700 "$profile_root"
fi
for dir in home config data cache state; do
    if [[ -L "$profile_root/$dir" || ( -e "$profile_root/$dir" && ! -O "$profile_root/$dir" ) ]]; then
        echo "DMS_NATIVE_RUN_BLOCKED: unsafe private profile directory" >&2
        exit 1
    fi
    mkdir -p -m 700 "$profile_root/$dir"
    chmod 700 "$profile_root/$dir"
done
[[ ! -L "$root/runtime" ]] || {
    echo "DMS_NATIVE_RUN_BLOCKED: symlinked private runtime directory" >&2
    exit 1
}
mkdir -p -m 700 "$root/runtime"
chmod 700 "$root/runtime"

# Verify the private built executable still functions when launched from
# a DIFFERENT path. The test uses local offline HTML, never the auth profile.
# No /usr/bin, PATH, systemd, DMS backend or package changes occur here.
if [[ "$relocation" == 1 ]]; then
    portable_dir="$root/portable-host"
    portable_bin="$portable_dir/quickshell"
    if [[ -L "$portable_dir" || ( -e "$portable_dir" && ! -O "$portable_dir" )
          || -L "$portable_bin" || ( -e "$portable_bin" && ! -O "$portable_bin" ) ]]; then
        echo "DMS_NATIVE_RELOCATION_BLOCKED: unsafe private staging path" >&2
        exit 1
    fi
    mkdir -p -m 700 "$portable_dir"
    chmod 700 "$portable_dir"
    install -m 700 "$binary" "$portable_bin"
    original_hash=$(sha256sum "$binary" | cut -d' ' -f1)
    portable_hash=$(sha256sum "$portable_bin" | cut -d' ' -f1)
    if [[ "$original_hash" != "$portable_hash" ]]; then
        echo "DMS_NATIVE_RELOCATION_BLOCKED: staged executable hash mismatch" >&2
        exit 1
    fi
    if ldd "$portable_bin" | grep -Fq "not found"; then
        echo "DMS_NATIVE_RELOCATION_BLOCKED: missing shared library in private copy" >&2
        exit 1
    fi
    binary="$portable_bin"
    # The test build's colon-only RUNPATH has empty directory elements;
    # run with a private, owned working directory, not arbitrary shell CWD.
    cd -- "$portable_dir"
    echo "DMS_NATIVE_RELOCATION_STAGED: $portable_bin"
    echo "DMS_NATIVE_RELOCATION_SHA256_MATCH: YES"
    echo "DMS_NATIVE_RELOCATION_TEST: actual DMS PluginPopout, offline only"
fi

# Run the stable per-user copy via its private 'qs' wrapper.
# This is an offline-only, isolated runtime test (NOT the running DMS).
if [[ "$staged" == 1 ]]; then
    if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
        echo "DMS_NATIVE_STAGED_BLOCKED: missing absolute HOME" >&2
        exit 1
    fi
    stage_root="$HOME/.local/share/dms-chatgpt-native-host/9b0f339-argc1-v01"
    staged_host="$stage_root/host/quickshell"
    staged_shim="$stage_root/bin/qs"
    for file in "$stage_root" "$stage_root/host" "$stage_root/bin" \
                "$staged_host" "$staged_shim"; do
        if [[ -L "$file" || ! -e "$file" || ! -O "$file" ]]; then
            echo "DMS_NATIVE_STAGED_BLOCKED: missing/untrusted staged host" >&2
            exit 1
        fi
    done
    if [[ ! -x "$staged_host" || ! -x "$staged_shim" ]]; then
        echo "DMS_NATIVE_STAGED_BLOCKED: private host not executable" >&2
        exit 1
    fi
    if readelf -d "$staged_host" | grep -Eq '\((RPATH|RUNPATH)\)'; then
        echo "DMS_NATIVE_STAGED_BLOCKED: RPATH/RUNPATH remains" >&2
        exit 1
    fi
    if ldd "$staged_host" | grep -Fq "not found"; then
        echo "DMS_NATIVE_STAGED_BLOCKED: missing shared library" >&2
        exit 1
    fi
    binary="$staged_shim"
    cd -- "$stage_root/host"
    echo "DMS_NATIVE_STAGED_HOST_TEST: $staged_host"
    echo "DMS_NATIVE_STAGED_QS_WRAPPER_TEST: $staged_shim"
    echo "DMS_NATIVE_STAGED_OFFLINE_ONLY"
fi

if [[ "$auth" == 1 ]]; then
    echo "DMS_NATIVE_AUTH_TEST: isolated login permitted; 300 second timeout"
    echo "DMS_NATIVE_AUTH_TEST: do not share credentials, tokens, or authentication URLs"
    echo "DMS_NATIVE_AUTH_TEST: local private profile at $profile_root"
elif [[ "$persistent" == 1 ]]; then
    echo "DMS_NATIVE_PERSISTENCE_TEST: https://chatgpt.com/; DO NOT SIGN IN"
    echo "DMS_NATIVE_PERSISTENCE_TEST: disk profile in private XDG directories"
    echo "DMS_NATIVE_PERSISTENCE_TEST: reject nonessential cookies, restart to check consent"
elif [[ "$online" == 1 ]]; then
    echo "DMS_NATIVE_PUBLIC_TEST: opening https://chatgpt.com/; DO NOT SIGN IN"
    echo "DMS_NATIVE_PUBLIC_TEST: off-the-record WebEngine profile"
else
    echo "DMS_NATIVE_TEST_STARTED: real PluginPopout; offline HTML only"
    echo "DMS_NATIVE_TEST_INSTRUCTIONS: click pill, type test, dismiss, reopen"
fi
echo "DMS_NATIVE_ISOLATION: private HOME, XDG and session DBus; DMS_SOCKET and NIRI_SOCKET blank"
echo "DMS_NATIVE_AUTO_STOP: $duration"
# The compositor socket is deliberately shared so Niri can show the test
# window; other user runtime sockets remain inaccessible via the private
# XDG_RUNTIME_DIR. This is not a kernel/filesystem security sandbox.
exec /usr/bin/env -i \
    PATH="/usr/bin:/bin" \
    HOME="$profile_root/home" \
    LANG="C.UTF-8" \
    XDG_RUNTIME_DIR="$root/runtime" \
    XDG_CONFIG_HOME="$profile_root/config" \
    XDG_DATA_HOME="$profile_root/data" \
    XDG_CACHE_HOME="$profile_root/cache" \
    XDG_STATE_HOME="$profile_root/state" \
    XDG_CURRENT_DESKTOP="DMS_NATIVE_OFFLINE_PROBE" \
    XDG_SESSION_TYPE="wayland" \
    WAYLAND_DISPLAY="$socket" \
    QT_QPA_PLATFORM="wayland" \
    GSETTINGS_BACKEND="memory" \
    DMS_NATIVE_ONLINE_PROBE="$online" \
    DMS_NATIVE_PERSISTENCE_PROBE="$persistent" \
    DMS_NATIVE_AUTH_PROBE="$auth" \
    DMS_SOCKET="" \
    NIRI_SOCKET="" \
    dbus-run-session -- \
    timeout --signal=TERM --kill-after=3s "$duration" \
    "$binary" --path "$harness"
