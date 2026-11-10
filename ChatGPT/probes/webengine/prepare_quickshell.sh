#!/usr/bin/env bash
# Prepare a private, pinned Quickshell argc=1 source build in /tmp.
# No installation, no DMS reload, and no changes to /usr/bin/quickshell.
set -euo pipefail

root=/tmp/dms-chatgpt-qs-v02-argc1
pin=9b0f339b19057f4731bf3b48293307d7ef241671
if [[ -L "$root" ]] || { [[ -e "$root" ]] && [[ ! -d "$root" ]]; }; then
  echo "Unsafe experiment directory; refusing" >&2
  exit 1
fi
mkdir -p "$root"
if [[ ! -e "$root/source" ]]; then
  git clone --depth 1 --branch master https://github.com/quickshell-mirror/quickshell.git "$root/source"
fi
if [[ ! -d "$root/source/.git" ]] || [[ -L "$root/source" ]]; then
  echo "Unexpected source directory; refusing" >&2
  exit 1
fi
current=$(git -C "$root/source" rev-parse HEAD)
if [[ "$current" != "$pin" ]]; then
  echo "Upstream source changed; expected reviewed commit $pin, got $current" >&2
  exit 1
fi
target="$root/source/src/launch/launch.cpp"
if [[ -L "$target" ]]; then
  echo "Refusing symlinked source file" >&2
  exit 1
fi
python3 - "$target" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old, new = "\tauto qArgC = 0;", "\tauto qArgC = 1;"
if s.count(old) == 1 and new not in s:
    p.write_text(s.replace(old, new), encoding="utf-8")
elif s.count(new) != 1 or old in s:
    raise SystemExit("Unexpected Quickshell argc line; refusing patch")
PY
git -C "$root/source" diff --check
if [[ "$(git -C "$root/source" diff --name-only)" != "src/launch/launch.cpp" ]]; then
  echo "Unexpected modifications in source checkout" >&2
  exit 1
fi
cmake -S "$root/source" -B "$root/build" -GNinja \
  -DCMAKE_BUILD_TYPE=Release -DCRASH_HANDLER=OFF -DUSE_JEMALLOC=OFF \
  -DWAYLAND=OFF -DX11=OFF -DI3=OFF -DSOCKETS=OFF \
  -DHYPRLAND=OFF -DSCREENCOPY=OFF \
  -DSERVICE_PIPEWIRE=OFF -DSERVICE_MPRIS=OFF \
  -DSERVICE_STATUS_NOTIFIER=OFF -DSERVICE_PAM=OFF \
  -DSERVICE_POLKIT=OFF -DSERVICE_GREETD=OFF -DSERVICE_UPOWER=OFF \
  -DSERVICE_NOTIFICATIONS=OFF -DBLUETOOTH=OFF -DNETWORK=OFF
echo "ISOLATED_QS_CONFIGURED: $root/build"
echo "NEXT: cmake --build $root/build -j2"
