#!/usr/bin/env bash
# Build a separate, complete argc=1 Quickshell host for native DMS.
# The original tested build-dms and staged production candidate are untouched.
# This only CONFIGURES a new build tree; never installs, switches or restarts DMS.
set -euo pipefail
umask 077

root=/tmp/dms-chatgpt-qs-v02-argc1
source_dir="$root/source"
build_dir="$root/build-dms-screencopy-v01"
pin=9b0f339b19057f4731bf3b48293307d7ef241671

for tool in git python3 cmake ninja pkg-config; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "DMS_SCREENCOPY_BUILD_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -L "$root" || -L "$source_dir" || -L "$build_dir" ||
      ! -O "$root" || ! -d "$source_dir/.git" ||
      ( -e "$build_dir" && ( ! -d "$build_dir" || ! -O "$build_dir" ) ) ]]; then
    echo "DMS_SCREENCOPY_BUILD_BLOCKED: unsafe or absent source/build directory" >&2
    exit 1
fi
if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$pin" ||
      "$(git -C "$source_dir" status --porcelain)" != " M src/launch/launch.cpp" ]]; then
    echo "DMS_SCREENCOPY_BUILD_BLOCKED: unreviewed source changes" >&2
    exit 1
fi
python3 - "$source_dir" <<'PY'
from pathlib import Path
import subprocess
import sys

src = Path(sys.argv[1])
file = src / "src/launch/launch.cpp"
original = subprocess.check_output(
    ["git", "-C", str(src), "show", "HEAD:src/launch/launch.cpp"],
    text=True,
)
before, after = "\tauto qArgC = 0;", "\tauto qArgC = 1;"
if original.count(before) != 1 or file.read_text() != original.replace(before, after):
    raise SystemExit("DMS_SCREENCOPY_BUILD_BLOCKED: argc patch differs from reviewed one")
PY
git -C "$source_dir" diff --check

# Screencopy needs GBM and Vulkan headers in addition to the dependencies
# already checked by the original DMS build script.
failed=0
for module in gbm libpipewire-0.3 glib-2.0 gobject-2.0 polkit-agent-1 polkit-gobject-1; do
    if ! pkg-config --exists "$module"; then
        echo "DMS_SCREENCOPY_DEPENDENCY_MISSING: $module" >&2
        failed=1
    fi
done
if [[ ! -f /usr/include/vulkan/vulkan_core.h ]]; then
    echo "DMS_SCREENCOPY_DEPENDENCY_MISSING: vulkan-headers" >&2
    failed=1
fi
[[ "$failed" == 0 ]] || exit 1

# Never point this script at the original build-dms tree. Verify that
# a pre-existing cache (if any) belongs to the intended source.
if [[ -f "$build_dir/CMakeCache.txt" ]]; then
    cached_src=$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$build_dir/CMakeCache.txt")
    if [[ "$cached_src" != "$source_dir" ]]; then
        echo "DMS_SCREENCOPY_BUILD_BLOCKED: mismatched cached source root" >&2
        exit 1
    fi
fi

cmake -S "$source_dir" -B "$build_dir" -GNinja \
  -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF \
  -DWAYLAND=ON -DWAYLAND_WLR_LAYERSHELL=ON \
  -DWAYLAND_SESSION_LOCK=ON -DWAYLAND_TOPLEVEL_MANAGEMENT=ON \
  -DSCREENCOPY=ON -DSCREENCOPY_ICC=ON -DSCREENCOPY_WLR=ON \
  -DSCREENCOPY_HYPRLAND_TOPLEVEL=ON \
  -DX11=OFF -DSOCKETS=ON \
  -DI3=ON -DI3_IPC=ON \
  -DHYPRLAND=ON -DHYPRLAND_IPC=ON \
  -DHYPRLAND_FOCUS_GRAB=ON -DHYPRLAND_GLOBAL_SHORTCUTS=ON \
  -DHYPRLAND_SURFACE_EXTENSIONS=ON \
  -DBLUETOOTH=ON -DNETWORK=OFF \
  -DSERVICE_MPRIS=ON -DSERVICE_NOTIFICATIONS=ON \
  -DSERVICE_PAM=ON -DSERVICE_PIPEWIRE=ON -DSERVICE_POLKIT=ON \
  -DSERVICE_STATUS_NOTIFIER=ON -DSERVICE_UPOWER=ON \
  -DSERVICE_GREETD=OFF

for feature in WAYLAND SCREENCOPY SCREENCOPY_ICC SCREENCOPY_WLR SCREENCOPY_HYPRLAND_TOPLEVEL; do
    if ! grep -Eq "^$feature:BOOL=(ON|TRUE)$" "$build_dir/CMakeCache.txt"; then
        echo "DMS_SCREENCOPY_BUILD_BLOCKED: $feature not enabled in final CMake cache" >&2
        exit 1
    fi
done
echo "DMS_SCREENCOPY_FULL_BUILD_CONFIGURED: $build_dir"
echo "DMS_SCREENCOPY_FLAG_CONFIRMED: ON"
echo "DMS_SCREENCOPY_ORIGINAL_BUILD_UNCHANGED"
echo "DMS_SCREENCOPY_NO_PRODUCTION_CHANGES"
echo "NEXT: cmake --build $build_dir -j2"
