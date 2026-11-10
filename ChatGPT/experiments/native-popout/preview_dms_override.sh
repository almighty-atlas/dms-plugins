#!/usr/bin/env bash
# Read-only preview for using a pinned private 'qs' ONLY in dms.service.
# There is intentionally NO apply/enable/restart operation in this script.
set -euo pipefail

if [[ "$#" != 1 || "$1" != "--preview" ]]; then
    echo "Usage: bash preview_dms_override.sh --preview" >&2
    exit 2
fi

version=9b0f339-argc1-v01
service=dms.service
private_root="$HOME/.local/share/dms-chatgpt-native-host/$version"
private_bin="$private_root/bin"
private_qs="$private_bin/qs"
private_host="$private_root/host/quickshell"
unit_dir="$HOME/.config/systemd/user/dms.service.d"
dropin="$unit_dir/50-chatgpt-private-qs.conf"

for cmd in systemctl readlink readelf ldd sha256sum tr sed grep stat; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "DMS_OVERRIDE_PREVIEW_BLOCKED: missing $cmd" >&2
        exit 1
    }
done

if [[ -z "${HOME:-}" || "$HOME" != /* || ! -O "$HOME" ]] ||
   [[ ! -d "$private_root" || ! -d "$private_bin" ||
      ! -f "$private_qs" || ! -f "$private_host" ||
      ! -x "$private_qs" || ! -x "$private_host" ]]; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: private host not staged" >&2
    exit 1
fi
for f in "$private_root" "$private_root/bin" "$private_root/host" \
         "$private_qs" "$private_host"; do
    if [[ -L "$f" || ! -O "$f" ]]; then
        echo "DMS_OVERRIDE_PREVIEW_BLOCKED: unowned or symlinked private host" >&2
        exit 1
    fi
done

if readelf -d "$private_host" | grep -Eq '\((RPATH|RUNPATH)\)'; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: private host has RPATH/RUNPATH" >&2
    exit 1
fi
if ldd "$private_host" | grep -Fq "not found"; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: missing linked Qt/system libraries" >&2
    exit 1
fi

active=$(systemctl --user show "$service" -p ActiveState --value)
fragment=$(systemctl --user show "$service" -p FragmentPath --value)
dropins=$(systemctl --user show "$service" -p DropInPaths --value)
pid=$(systemctl --user show "$service" -p MainPID --value)
if [[ "$active" != "active" ||
      "$fragment" != "/usr/lib/systemd/user/dms.service" ||
      -n "$dropins" || ! "$pid" =~ ^[0-9]+$ || "$pid" == 0 ]] ||
   [[ "$(readlink -f "/proc/$pid/exe" || true)" != "/usr/bin/dms" ]]; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: live DMS service differs from inspected baseline" >&2
    exit 1
fi

# Use exactly the current DMS backend PATH rather than guessing paths:
# systemd Environment= does NOT expand $PATH. Restrict to plain paths so
# quoting/specifier expansion cannot change the generated drop-in.
live_path=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^PATH=//p')
if [[ -z "$live_path" || "$live_path" == *"::"* ||
      "$live_path" == :* || "$live_path" == *: ||
      ! "$live_path" =~ ^[a-zA-Z0-9_/:.+-]+$ ]]; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: unsupported DMS PATH syntax" >&2
    exit 1
fi

if [[ -L "$unit_dir" || -L "$dropin" || -e "$dropin" ]]; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: existing or unsafe drop-in" >&2
    exit 1
fi
if [[ -d "$unit_dir" && ! -O "$unit_dir" ]]; then
    echo "DMS_OVERRIDE_PREVIEW_BLOCKED: override directory not owned by user" >&2
    exit 1
fi

printf 'DMS_OVERRIDE_PREVIEW_CHECKS: PASSED\n'
printf 'DMS_OVERRIDE_PREVIEW_MAINPID: %s\n' "$pid"
printf 'DMS_OVERRIDE_PREVIEW_PRIVATE_HOST_SHA256: %s\n' "$(sha256sum "$private_host" | cut -d' ' -f1)"
printf 'DMS_OVERRIDE_PREVIEW_DESTINATION: %s\n' "$dropin"
printf '\nPROPOSED_CONTENT_BEGIN\n'
printf '[Service]\nEnvironment="PATH=%s:%s"\n' "$private_bin" "$live_path"
printf 'PROPOSED_CONTENT_END\n'
printf '\nDMS_OVERRIDE_PREVIEW_ONLY: NO FILE WRITTEN; NO DAEMON RELOAD; NO RESTART\n'
printf 'DMS_OVERRIDE_EFFECT_IF_ACTIVATED: DMS child qs uses private binary; other processes inherit modified PATH\n'
printf 'DMS_OVERRIDE_ROLLBACK_PLAN: delete ONLY the exact new drop-in, daemon-reload, then restart DMS\n'
printf 'DMS_OVERRIDE_RISK: DMS restart temporarily stops the bar and its child processes, including Bitwarden helper\n'
printf 'DMS_OVERRIDE_NO_ACTIVATION: explicit approval is required before any live change\n'
