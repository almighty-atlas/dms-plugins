#!/usr/bin/env bash
# Safe comparison of the installed Quickshell host with the isolated patched
# test binary. --probe launches only QuickshellArgsProbe.qml (NO WebEngine).
# No installation, replacement, DMS restart, login, or credentials.
set -euo pipefail

mode=metadata
if [[ "${1:-}" == "--probe" && "$#" == 1 ]]; then
  mode=probe
elif [[ "$#" != 0 ]]; then
  echo "Usage: bash host_preflight.sh [--probe]" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/../../.." && pwd -P)
probe_qml="$repo_root/ChatGPT/probes/webengine/QuickshellArgsProbe.qml"
patched=/tmp/dms-chatgpt-qs-v02-argc1/build-dms/src/quickshell

if ! command -v quickshell >/dev/null 2>&1; then
  echo "DMS_HOST_PRECHECK_BLOCKED: system Quickshell not in PATH" >&2
  exit 1
fi
installed=$(command -v quickshell)

echo "DMS_HOST_INSTALLED: $installed"
echo "DMS_HOST_TESTED_PATCHED: $patched"
for name in quickshell quickshell-git; do
  if command -v pacman >/dev/null 2>&1 && pacman -Qq "$name" >/dev/null 2>&1; then
    echo "DMS_HOST_PACKAGE: $(pacman -Q "$name")"
  fi
done

for bin in "$installed" "$patched"; do
  if [[ -f "$bin" && -x "$bin" ]]; then
    echo "DMS_HOST_BINARY_SHA256: $(sha256sum "$bin" | cut -d' ' -f1) ($bin)"
  else
    echo "DMS_HOST_BINARY_MISSING: $bin"
  fi
done

if [[ "$mode" == metadata ]]; then
  echo "DMS_HOST_ARGC: UNVERIFIED_IN_THIS_RUN"
  echo "DMS_HOST_NO_RUNTIME_LAUNCHED"
  echo "NEXT: bash $script_dir/host_preflight.sh --probe"
  exit 0
fi

if [[ ! -f "$probe_qml" || ! -x "$patched" ]]; then
  echo "DMS_HOST_PRECHECK_BLOCKED: missing safe QML probe or patched test host" >&2
  exit 1
fi
if ! command -v timeout >/dev/null 2>&1; then
  echo "DMS_HOST_PRECHECK_BLOCKED: timeout required" >&2
  exit 1
fi

# Only output a fixed argument-count status. Never print argv strings,
# Quickshell logs, user shell state, auth data, or browser cookies.
probe_host() {
  local label="$1" bin="$2" trace ret=0
  trace=$(mktemp -t dms-chatgpt-host-args.XXXXXXXX)
  chmod 600 "$trace"
  timeout --signal=TERM --kill-after=2s 6s "$bin" \
    --path "$probe_qml" >"$trace" 2>&1 || ret=$?

  if grep -Fq "DMS_QS_ARGC_ZERO" "$trace"; then
    echo "DMS_HOST_${label}_ARGC: ZERO_UNSAFE_FOR_WEBENGINE"
  elif grep -Fq "DMS_QS_ARGC_NONZERO" "$trace"; then
    echo "DMS_HOST_${label}_ARGC: NONZERO_WEBENGINE_PREREQUISITE_MET"
  else
    echo "DMS_HOST_${label}_ARGC: INCONCLUSIVE (exit $ret)"
  fi
  rm -f -- "$trace"
}

probe_host INSTALLED "$installed"
probe_host PATCHED "$patched"
echo "DMS_HOST_PROBE_ONLY_NO_WEBENGINE"
echo "DMS_HOST_NO_SYSTEM_CHANGES"
echo "DMS_HOST_NOTE: argc>=1 is necessary, not proof of compatible DMS QML modules."
