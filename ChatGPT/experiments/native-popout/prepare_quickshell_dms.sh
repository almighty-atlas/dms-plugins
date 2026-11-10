#!/usr/bin/env bash
# Configure the isolated argc=1 Quickshell source for DMS QML imports.
# Does not install packages, start DMS or replace the running shell.
set -euo pipefail
root=/tmp/dms-chatgpt-qs-v02-argc1
source_dir="$root/source"
build_dir="$root/build-dms"
pin=9b0f339b19057f4731bf3b48293307d7ef241671

if [[ -L "$root" || -L "$source_dir" || -L "$build_dir" ]] ||
   [[ ! -d "$source_dir/.git" ]] ||
   [[ -e "$build_dir" && ! -d "$build_dir" ]]; then
    echo "DMS_HOST_BUILD_BLOCKED: unsafe or absent source/build directory" >&2
    exit 1
fi
[[ "$(git -C "$source_dir" rev-parse HEAD)" == "$pin" ]] || {
    echo "DMS_HOST_BUILD_BLOCKED: unexpected source revision" >&2
    exit 1
}
[[ "$(git -C "$source_dir" status --porcelain)" == " M src/launch/launch.cpp" ]] || {
    echo "DMS_HOST_BUILD_BLOCKED: unexpected modifications" >&2
    exit 1
}

python3 - "$source_dir" <<'PY'
import pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
path = root / "src/launch/launch.cpp"
original = subprocess.check_output(
    ["git", "-C", str(root), "show", "HEAD:src/launch/launch.cpp"], text=True)
before, after = "\tauto qArgC = 0;", "\tauto qArgC = 1;"
if original.count(before) != 1 or path.read_text() != original.replace(before, after):
    raise SystemExit("DMS_HOST_BUILD_BLOCKED: source differs from one-line argc patch")
PY
git -C "$source_dir" diff --check

failed=0
for module in libpipewire-0.3 glib-2.0 gobject-2.0 polkit-agent-1 polkit-gobject-1; do
    if ! pkg-config --exists "$module"; then
        echo "DMS_HOST_DEPENDENCY_MISSING: $module" >&2
        failed=1
    fi
done
[[ "$failed" == 0 ]] || exit 1

cmake -S "$source_dir" -B "$build_dir" -GNinja \
  -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF \
  -DWAYLAND=ON -DWAYLAND_WLR_LAYERSHELL=ON \
  -DWAYLAND_SESSION_LOCK=ON -DWAYLAND_TOPLEVEL_MANAGEMENT=ON \
  -DSCREENCOPY=OFF -DX11=OFF -DSOCKETS=ON \
  -DI3=ON -DI3_IPC=ON \
  -DHYPRLAND=ON -DHYPRLAND_IPC=ON \
  -DHYPRLAND_FOCUS_GRAB=ON -DHYPRLAND_GLOBAL_SHORTCUTS=ON \
  -DHYPRLAND_SURFACE_EXTENSIONS=ON \
  -DBLUETOOTH=ON -DNETWORK=OFF \
  -DSERVICE_MPRIS=ON -DSERVICE_NOTIFICATIONS=ON \
  -DSERVICE_PAM=ON -DSERVICE_PIPEWIRE=ON -DSERVICE_POLKIT=ON \
  -DSERVICE_STATUS_NOTIFIER=ON -DSERVICE_UPOWER=ON \
  -DSERVICE_GREETD=OFF

echo "DMS_HOST_CONFIGURED: $build_dir"
echo "NO_DMS_OR_BROWSER_STARTED"
echo "NO_INSTALLED_QUICKSHELL_CHANGED"
echo "NEXT: cmake --build $build_dir -j2"
