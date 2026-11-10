#!/usr/bin/env bash
# User-owned, versioned STAGING ONLY of the corrected DMS-compatible QS.
# No systemd, no live DMS, no original v01 host, no auth/browser changes.
set -euo pipefail
umask 077

if [[ "$#" != 1 || ( "$1" != "--stage" && "$1" != "--verify" ) ]]; then
    echo "Usage: bash stage_private_screencopy_host.sh --stage|--verify" >&2
    exit 2
fi
mode="$1"
pin=9b0f339b19057f4731bf3b48293307d7ef241671
version=9b0f339-argc1-screencopy-v02
root=/tmp/dms-chatgpt-qs-v02-argc1
source_dir="$root/source"
build_dir="$root/build-dms-screencopy-v01"
source_bin="$build_dir/src/quickshell"
base="$HOME/.local/share/dms-chatgpt-native-host"
stage="$base/$version"

for tool in git python3 sha256sum readelf ldd patchelf mktemp install; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "DMS_SCREENCOPY_STAGE_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -z "${HOME:-}" || "$HOME" != /* || ! -d "$HOME" ||
      ! -O "$HOME" || -L "$HOME" ]] ||
   [[ ! "$HOME" =~ ^/[a-zA-Z0-9_./+-]+$ ]]; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: unsafe HOME" >&2
    exit 1
fi
for dir in "$HOME/.local" "$HOME/.local/share" "$base"; do
    if [[ -L "$dir" || ( -e "$dir" && ( ! -d "$dir" || ! -O "$dir" ) ) ]]; then
        echo "DMS_SCREENCOPY_STAGE_BLOCKED: unsafe destination component" >&2
        exit 1
    fi
    if [[ ! -d "$dir" ]]; then
        mkdir -m 700 -- "$dir"
    fi
done
chmod 700 "$base"

verify_stage() {
    local host="$stage/host/quickshell"
    local shim="$stage/bin/qs"
    local sha_file="$stage/host.sha256"
    for dir in "$stage" "$stage/host" "$stage/bin"; do
        if [[ -L "$dir" || ! -d "$dir" || ! -O "$dir" ]]; then
            echo "DMS_SCREENCOPY_VERIFY_BLOCKED: unsafe staged directory" >&2
            return 1
        fi
    done
    for file in "$host" "$shim" "$sha_file"; do
        if [[ -L "$file" || ! -f "$file" || ! -O "$file" ]]; then
            echo "DMS_SCREENCOPY_VERIFY_BLOCKED: unsafe staged file" >&2
            return 1
        fi
    done
    [[ -x "$host" && -x "$shim" ]] || {
        echo "DMS_SCREENCOPY_VERIFY_BLOCKED: staged executable not executable" >&2
        return 1
    }
    local recorded actual
    recorded=$(cat "$sha_file")
    actual=$(sha256sum "$host" | cut -d' ' -f1)
    if [[ ! "$recorded" =~ ^[0-9a-f]{64}$ || "$actual" != "$recorded" ]]; then
        echo "DMS_SCREENCOPY_VERIFY_BLOCKED: staged executable checksum mismatch" >&2
        return 1
    fi
    local expected_shim
    expected_shim=$(printf '%s\n' \
        '#!/bin/sh' \
        'set -eu' \
        'exec "$(dirname -- "$0")/../host/quickshell" "$@"')
    if [[ "$(cat "$shim")" != "$expected_shim" ]]; then
        echo "DMS_SCREENCOPY_VERIFY_BLOCKED: staged qs wrapper differs" >&2
        return 1
    fi
    if readelf -d "$host" | grep -Eq '\((RPATH|RUNPATH)\)' ||
       ldd "$host" | grep -Fq "not found"; then
        echo "DMS_SCREENCOPY_VERIFY_BLOCKED: unsafe RPATH or missing shared library" >&2
        return 1
    fi
    echo "DMS_SCREENCOPY_PRIVATE_HOST_VERIFIED: YES"
    echo "DMS_SCREENCOPY_PRIVATE_HOST: $host"
    echo "DMS_SCREENCOPY_PRIVATE_SHA256: $actual"
    echo "DMS_SCREENCOPY_PRIVATE_NO_SERVICE_CHANGE"
}
if [[ "$mode" == "--verify" ]]; then
    verify_stage
    exit
fi

# Fail closed: never overwrite the retired/other version or re-stage an
# existing v02 target. The source is a pinned, one-line argc=1 checkout.
if [[ -e "$stage" || -L "$stage" ||
      -L "$root" || -L "$source_dir" || -L "$build_dir" ||
      -L "$source_bin" || ! -O "$build_dir" ||
      ! -f "$source_bin" || ! -O "$source_bin" || ! -x "$source_bin" ||
      ! -d "$source_dir/.git" ||
      "$(git -C "$source_dir" rev-parse HEAD)" != "$pin" ||
      "$(git -C "$source_dir" status --porcelain)" != " M src/launch/launch.cpp" ]]; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: existing stage or unreviewed build" >&2
    exit 1
fi
python3 - "$source_dir" <<'PY'
from pathlib import Path
import subprocess
import sys
root = Path(sys.argv[1])
p = root / "src/launch/launch.cpp"
original = subprocess.check_output(
    ["git", "-C", str(root), "show", "HEAD:src/launch/launch.cpp"],
    text=True)
before, after = "\tauto qArgC = 0;", "\tauto qArgC = 1;"
if original.count(before) != 1 or p.read_text() != original.replace(before, after):
    raise SystemExit("DMS_SCREENCOPY_STAGE_BLOCKED: unexpected argc source patch")
PY
git -C "$source_dir" diff --check
for feature in WAYLAND WAYLAND_WLR_LAYERSHELL SCREENCOPY SCREENCOPY_ICC SCREENCOPY_WLR SCREENCOPY_HYPRLAND_TOPLEVEL; do
    grep -Eq "^$feature:BOOL=(ON|TRUE)$" "$build_dir/CMakeCache.txt" || {
        echo "DMS_SCREENCOPY_STAGE_BLOCKED: $feature disabled" >&2
        exit 1
    }
done
if readelf -d "$source_bin" | grep -Eq 'NEEDED.*libquickshell.*not-known'; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: unexpected linked host" >&2
    exit 1
fi
if ldd "$source_bin" | grep -Fq "not found"; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: missing linked libraries" >&2
    exit 1
fi

scratch=$(mktemp -d -- "$base/.new-screencopy-host.XXXXXXXX")
cleanup() { [[ ! -d "$scratch" ]] || rm -rf -- "$scratch"; }
trap cleanup EXIT
mkdir -m 700 "$scratch/host" "$scratch/bin"
install -m 700 -- "$source_bin" "$scratch/host/quickshell"
patchelf --remove-rpath "$scratch/host/quickshell"
if readelf -d "$scratch/host/quickshell" | grep -Eq '\((RPATH|RUNPATH)\)' ||
   ldd "$scratch/host/quickshell" | grep -Fq "not found"; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: relocated host has RPATH or missing library" >&2
    exit 1
fi
cat > "$scratch/bin/qs" <<'SHIM'
#!/bin/sh
set -eu
exec "$(dirname -- "$0")/../host/quickshell" "$@"
SHIM
chmod 700 "$scratch/bin/qs"
sha256sum "$scratch/host/quickshell" | cut -d' ' -f1 > "$scratch/host.sha256"
chmod 600 "$scratch/host.sha256"

# Rename into a NEW version only; it is never used by systemd here.
if [[ -e "$stage" || -L "$stage" ]]; then
    echo "DMS_SCREENCOPY_STAGE_BLOCKED: target appeared during staging" >&2
    exit 1
fi
mv -T -- "$scratch" "$stage"
verify_stage
echo "DMS_SCREENCOPY_PRIVATE_NEW_VERSION: $version"
echo "DMS_SCREENCOPY_PRIVATE_OLD_VERSION_UNCHANGED"
echo "DMS_SCREENCOPY_PRIVATE_NO_PRODUCTION_ACTIVATION"
