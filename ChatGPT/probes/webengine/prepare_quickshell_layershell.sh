#!/usr/bin/env bash
# Reconfigure the reviewed argc=1 Quickshell *test source* for Wayland layer-shell.
# Entire build stays in /tmp; never install or reload system Quickshell/DMS.
set -euo pipefail

root=/tmp/dms-chatgpt-qs-v02-argc1
source_dir="$root/source"
build_dir="$root/build-layer"
pin=9b0f339b19057f4731bf3b48293307d7ef241671

if [[ ! -d "$source_dir/.git" ]] || [[ -L "$root" ]] ||
   [[ -L "$source_dir" ]] || [[ -L "$build_dir" ]]; then
    echo "Missing or unsafe isolated Quickshell source/build path" >&2
    exit 1
fi

actual=$(git -C "$source_dir" rev-parse HEAD)
if [[ "$actual" != "$pin" ]]; then
    echo "Unexpected upstream revision: $actual" >&2
    exit 1
fi
if [[ "$(git -C "$source_dir" diff --name-only)" != "src/launch/launch.cpp" ]]; then
    echo "Unexpected Quickshell source changes" >&2
    exit 1
fi
if [[ "$(git -C "$source_dir" status --porcelain | wc -l)" -ne 1 ]]; then
    echo "Expected exactly one modified Quickshell source file" >&2
    exit 1
fi
if ! grep -Fq 'auto qArgC = 1;' "$source_dir/src/launch/launch.cpp"; then
    echo "Reviewed argc=1 source patch missing" >&2
    exit 1
fi
git -C "$source_dir" diff --check

cmake -S "$source_dir" -B "$build_dir" -GNinja \
  -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF \
  -DWAYLAND=ON -DWAYLAND_WLR_LAYERSHELL=ON \
  -DWAYLAND_SESSION_LOCK=OFF -DWAYLAND_TOPLEVEL_MANAGEMENT=OFF \
  -DX11=OFF -DI3=OFF -DSOCKETS=OFF \
  -DHYPRLAND=OFF -DSCREENCOPY=OFF \
  -DSERVICE_PIPEWIRE=OFF -DSERVICE_MPRIS=OFF \
  -DSERVICE_STATUS_NOTIFIER=OFF -DSERVICE_PAM=OFF \
  -DSERVICE_POLKIT=OFF -DSERVICE_GREETD=OFF -DSERVICE_UPOWER=OFF \
  -DSERVICE_NOTIFICATIONS=OFF -DBLUETOOTH=OFF -DNETWORK=OFF

echo "ISOLATED_QS_LAYERSHELL_CONFIGURED: $build_dir"
echo "NEXT: cmake --build $build_dir -j2"
