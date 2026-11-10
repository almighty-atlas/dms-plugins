#!/usr/bin/env bash
# Install only the pinned, locally built argc=1 Quickshell host into
# a versioned *user-owned* private location. NO service/desktop changes.
# This deliberately never uses sudo, pacman, or live DMS IPC.
set -euo pipefail
umask 077

if [[ "$#" != 1 || "$1" != "--stage" ]]; then
    echo "Usage: bash stage_private_host.sh --stage" >&2
    exit 2
fi

source_dir=/tmp/dms-chatgpt-qs-v02-argc1/source
source_bin=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell
expected_commit=9b0f339b19057f4731bf3b48293307d7ef241671
expected_sha256=63e258a5b089565b9a93feca02bce7d5dc6602e719d2c66997356643601290f4
version=9b0f339-argc1-v01

for command in git sha256sum patchelf readelf ldd install mktemp cmp; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "DMS_PRIVATE_HOST_BLOCKED: missing tool $command" >&2
        exit 1
    fi
done

if [[ -z "${HOME:-}" || "$HOME" != /* || ! -d "$HOME" ||
      ! -O "$HOME" || -L "$source_bin" || ! -f "$source_bin" ||
      ! -O "$source_bin" || ! -x "$source_bin" ||
      ! -d "$source_dir/.git" ]]; then
    echo "DMS_PRIVATE_HOST_BLOCKED: unsafe HOME or patched source" >&2
    exit 1
fi
if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$expected_commit" ]]; then
    echo "DMS_PRIVATE_HOST_BLOCKED: unexpected patched source revision" >&2
    exit 1
fi
source_sha=$(sha256sum "$source_bin" | cut -d' ' -f1)
if [[ "$source_sha" != "$expected_sha256" ]]; then
    echo "DMS_PRIVATE_HOST_BLOCKED: source binary differs from user-tested build" >&2
    exit 1
fi

# Verify every path component under HOME before creating the private host.
# Do NOT change permissions on pre-existing ~/.local or ~/.local/share.
base="$HOME/.local/share/dms-chatgpt-native-host"
stage="$base/$version"
for dir in "$HOME/.local" "$HOME/.local/share" "$base" "$stage" \
           "$stage/host" "$stage/bin"; do
    if [[ -L "$dir" || ( -e "$dir" && ( ! -d "$dir" || ! -O "$dir" ) ) ]]; then
        echo "DMS_PRIVATE_HOST_BLOCKED: untrusted destination component" >&2
        exit 1
    fi
    if [[ ! -e "$dir" ]]; then
        mkdir -m 700 -- "$dir"
    fi
done
chmod 700 "$base" "$stage" "$stage/host" "$stage/bin"

host="$stage/host/quickshell"
shim="$stage/bin/qs"
for file in "$host" "$shim"; do
    if [[ -L "$file" || ( -e "$file" && ( ! -f "$file" || ! -O "$file" ) ) ]]; then
        echo "DMS_PRIVATE_HOST_BLOCKED: untrusted staged file" >&2
        exit 1
    fi
done

# Only the new copy is modified: remove the colon-only / empty RUNPATH
# entries (possible working-directory library lookup). Stock QS untouched.
scratch=$(mktemp -d -- "$stage/.staging.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
install -m 700 -- "$source_bin" "$scratch/quickshell"
patchelf --remove-rpath "$scratch/quickshell"
if readelf -d "$scratch/quickshell" | grep -Eq '\((RPATH|RUNPATH)\)'; then
    echo "DMS_PRIVATE_HOST_BLOCKED: staged binary still has RPATH/RUNPATH" >&2
    exit 1
fi
if ldd "$scratch/quickshell" | grep -Fq "not found"; then
    echo "DMS_PRIVATE_HOST_BLOCKED: missing library after RUNPATH cleanup" >&2
    exit 1
fi

cat > "$scratch/qs" <<'SHIM'
#!/bin/sh
set -eu
# PATH resolves this wrapper in a DMS-service-scoped private bin directory.
exec "$(dirname -- "$0")/../host/quickshell" "$@"
SHIM
chmod 700 "$scratch/qs"

# Never overwrite a versioned staged host. Re-running must produce
# exactly the same executable and wrapper or fail closed.
if [[ -e "$host" ]]; then
    if ! cmp -s "$scratch/quickshell" "$host"; then
        echo "DMS_PRIVATE_HOST_BLOCKED: existing staged host differs" >&2
        exit 1
    fi
else
    mv -- "$scratch/quickshell" "$host"
fi
if [[ -e "$shim" ]]; then
    if ! cmp -s "$scratch/qs" "$shim"; then
        echo "DMS_PRIVATE_HOST_BLOCKED: existing private qs wrapper differs" >&2
        exit 1
    fi
else
    mv -- "$scratch/qs" "$shim"
fi

if [[ ! -x "$host" || ! -x "$shim" ]]; then
    echo "DMS_PRIVATE_HOST_BLOCKED: private host not executable" >&2
    exit 1
fi
if readelf -d "$host" | grep -Eq '\((RPATH|RUNPATH)\)'; then
    echo "DMS_PRIVATE_HOST_BLOCKED: destination still has RPATH/RUNPATH" >&2
    exit 1
fi
echo "DMS_PRIVATE_HOST_STAGED: $host"
echo "DMS_PRIVATE_QS_WRAPPER: $shim"
echo "DMS_PRIVATE_HOST_SHA256: $(sha256sum "$host" | cut -d' ' -f1)"
echo "DMS_PRIVATE_HOST_RUNPATH: ABSENT"
echo "DMS_PRIVATE_HOST_NO_SERVICE_CHANGE"
echo "DMS_PRIVATE_HOST_NO_PACKAGE_CHANGE"
echo "DMS_PRIVATE_HOST_NEXT: run_native_popout.sh --staged-host-check"
