#!/usr/bin/env bash
# Clone exact DMS source for a source-level native popup experiment, under /tmp.
# This script DOES NOT launch Quickshell or DMS, install or register plugins.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
root=/tmp/dms-chatgpt-native-v02
pin=e46ccbc1d58930d6a189cd1c90b276db2d64bf42
source_dir="$root/dux-shell"
qml_root="$source_dir/quickshell"

if [[ -L "$root" ]] || { [[ -e "$root" ]] && [[ ! -O "$root" ]]; }; then
  echo "Unsafe sandbox root (symlink or wrong owner)" >&2
  exit 1
fi
mkdir -p -m 700 "$root"
if [[ -L "$source_dir" ]] || { [[ -e "$source_dir" ]] && [[ ! -d "$source_dir/.git" ]]; }; then
  echo "Unexpected DMS source directory" >&2
  exit 1
fi
if [[ ! -d "$source_dir/.git" ]]; then
  mkdir "$source_dir"
  git -C "$source_dir" init -q
  git -C "$source_dir" remote add origin https://github.com/duxlabs-dev/dux-shell.git
  git -C "$source_dir" fetch -q --depth 1 origin "$pin"
  git -C "$source_dir" checkout -q --detach FETCH_HEAD
fi
actual=$(git -C "$source_dir" rev-parse HEAD)
if [[ "$actual" != "$pin" ]]; then
  echo "Unexpected DMS revision: $actual" >&2
  exit 1
fi
# Leave an already-modified checkout alone. Re-run is idempotent for our files.
if [[ -n "$(git -C "$source_dir" diff --name-only)" ]]; then
  echo "Tracked DMS source changes detected; refusing overwrite" >&2
  exit 1
fi
mkdir -p "$qml_root/ChatGPTNativeProbe" "$root/config" "$root/data" "$root/cache" "$root/state" "$root/home"
chmod 700 "$root/config" "$root/data" "$root/cache" "$root/state" "$root/home"
cp -- "$script_dir/Widget.qml" "$qml_root/ChatGPTNativeProbe/Widget.qml"
cp -- "$script_dir/ChatGPTNativeHarness.qml" "$qml_root/ChatGPTNativeHarness.qml"
printf '%s\n' "DMS_NATIVE_SANDBOX_PREPARED: $root" \
  "DMS_SOURCE_SHA: $actual" \
  "NO_SHELL_OR_BROWSER_STARTED" \
  "NO_SYSTEM_OR_USER_DMS_CONFIG_CHANGED"
