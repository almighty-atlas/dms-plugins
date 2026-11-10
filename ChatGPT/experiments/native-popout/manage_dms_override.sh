#!/usr/bin/env bash
# DMS-only candidate host switch; no action without an explicit mode.
# --activate requires a terminal confirmation, arms independent auto-rollback.
set -euo pipefail
umask 077

mode="${1:-}"
if [[ "$#" != 1 || ( "$mode" != "--activate" &&
                       "$mode" != "--confirm" &&
                       "$mode" != "--rollback" ) ]]; then
    echo "Usage: bash manage_dms_override.sh --activate|--confirm|--rollback" >&2
    exit 2
fi
if [[ -z "${HOME:-}" || "$HOME" != /* ||
      ! "$HOME" =~ ^/[a-zA-Z0-9_./+-]+$ || ! -d "$HOME" || ! -O "$HOME" ]]; then
    echo "DMS_SWITCH_BLOCKED: unsafe HOME" >&2
    exit 1
fi

root="$HOME/.local/share/dms-chatgpt-native-host/9b0f339-argc1-v01"
host="$root/host/quickshell"
bin="$root/bin"
control="$root/control"
persistent="$control/manage_dms_override.sh"
dropdir="$HOME/.config/systemd/user/dms.service.d"
dropin="$dropdir/50-chatgpt-private-qs.conf"
marker="$control/override.sha256"
timer_base=dms-chatgpt-native-autorevert
timer="$timer_base.timer"
expected_host_sha=af356f3885e51fa0f4a40697648cc97ca19e24342ca990c01a340d34092f696a

for tool in systemctl sha256sum readlink sed tr grep; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "DMS_SWITCH_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -L "$dropdir" || -L "$dropin" ||
      -L "$control" || ( -e "$control" && ( ! -d "$control" || ! -O "$control" ) ) ]]; then
    echo "DMS_SWITCH_BLOCKED: unsafe controller or drop-in path" >&2
    exit 1
fi

# Emergency and scheduled rollback do NOT require the private binary
# to be present or functional. Only this managed, checksum-matched drop-in
# is removed; unrelated systemd overrides stay untouched.
rollback() {
    if [[ ! -f "$marker" || -L "$marker" || ! -O "$marker" ]]; then
        echo "DMS_ROLLBACK_BLOCKED: checksum marker missing or unsafe" >&2
        exit 1
    fi
    local expected
    expected=$(cat -- "$marker")
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
        echo "DMS_ROLLBACK_BLOCKED: malformed checksum" >&2
        exit 1
    fi
    if [[ -e "$dropin" ]]; then
        if [[ ! -f "$dropin" || ! -O "$dropin" ||
              "$(sha256sum "$dropin" | cut -d' ' -f1)" != "$expected" ]]; then
            echo "DMS_ROLLBACK_BLOCKED: drop-in changed; inspect from TTY" >&2
            exit 1
        fi
        rm -- "$dropin"
    fi
    systemctl --user daemon-reload
    systemctl --user stop "$timer" >/dev/null 2>&1 || true
    systemctl --user restart dms.service
    rm -- "$marker"
    echo "DMS_ROLLBACK_APPLIED: original DMS service startup restored"
    echo "DMS_ROLLBACK_VERIFY: readlink -f /proc/<new-qs-pid>/exe"
}
if [[ "$mode" == "--rollback" ]]; then
    rollback
    exit 0
fi

# --confirm requires actual active private Quickshell child and armed timer.
if [[ "$mode" == "--confirm" ]]; then
    command -v pgrep >/dev/null || exit 1
    if [[ ! -f "$marker" || -L "$marker" ||
          ! -f "$dropin" || -L "$dropin" ||
          ! -O "$marker" || ! -O "$dropin" ]]; then
        echo "DMS_CONFIRM_BLOCKED: missing managed state" >&2
        exit 1
    fi
    expected=$(cat -- "$marker")
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ||
          "$(sha256sum "$dropin" | cut -d' ' -f1)" != "$expected" ]]; then
        echo "DMS_CONFIRM_BLOCKED: drop-in mismatch" >&2
        exit 1
    fi
    if ! systemctl --user is-active --quiet "$timer" ||
       ! systemctl --user is-active --quiet dms.service; then
        echo "DMS_CONFIRM_BLOCKED: service or rollback timer not active" >&2
        exit 1
    fi
    pid=$(systemctl --user show dms.service -p MainPID --value)
    if [[ ! "$pid" =~ ^[0-9]+$ || "$pid" == 0 ]]; then
        echo "DMS_CONFIRM_BLOCKED: invalid DMS PID" >&2
        exit 1
    fi
    found=0
    for child in $(pgrep -P "$pid" || true); do
        if [[ "$(readlink -f "/proc/$child/exe" 2>/dev/null || true)" == "$host" ]]; then
            found=1
            break
        fi
    done
    if [[ "$found" != 1 ]]; then
        echo "DMS_CONFIRM_BLOCKED: no private QS frontend child" >&2
        exit 1
    fi
    systemctl --user stop "$timer"
    echo "DMS_SWITCH_CONFIRMED: private QS is the live DMS frontend"
    echo "DMS_SWITCH_AUTOREVERT_CANCELED"
    echo "DMS_SWITCH_MANUAL_ROLLBACK: bash $persistent --rollback"
    exit 0
fi

# Activation is only allowed from the checked-out source, not from the
# persistent controller. The preview is our shared baseline validator.
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
preview="$source_dir/preview_dms_override.sh"
for tool in systemd-run mktemp install ln cmp; do
    command -v "$tool" >/dev/null || {
        echo "DMS_SWITCH_BLOCKED: missing $tool" >&2
        exit 1
    }
done
if [[ -L "$0" || ! -f "$0" || ! -O "$0" ||
      -L "$preview" || ! -f "$preview" ||
      ! -f "$host" || -L "$host" || ! -O "$host" ||
      "$(sha256sum "$host" | cut -d' ' -f1)" != "$expected_host_sha" ]]; then
    echo "DMS_SWITCH_BLOCKED: reviewed source/private host unavailable" >&2
    exit 1
fi
if ! preview_out=$(bash "$preview" --preview); then
    echo "DMS_SWITCH_BLOCKED: DMS preflight rejected the switch" >&2
    exit 1
fi
if [[ "$preview_out" != *"DMS_OVERRIDE_PREVIEW_CHECKS: PASSED"* ||
      "$preview_out" != *"DMS_OVERRIDE_PREVIEW_DESTINATION: $dropin"* ]]; then
    echo "DMS_SWITCH_BLOCKED: unexpected preview output" >&2
    exit 1
fi
pid=$(systemctl --user show dms.service -p MainPID --value)
live_path=$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^PATH=//p')
expected_ini=$(printf '[Service]\nEnvironment="PATH=%s:%s"\n' "$bin" "$live_path")
shown_ini=$(printf '%s\n' "$preview_out" | sed -n '/^PROPOSED_CONTENT_BEGIN$/,/^PROPOSED_CONTENT_END$/{/^PROPOSED_CONTENT_BEGIN$/d;/^PROPOSED_CONTENT_END$/d;p;}')
if [[ "$shown_ini" != "$expected_ini" ]]; then
    echo "DMS_SWITCH_BLOCKED: proposed drop-in differs from preflight" >&2
    exit 1
fi
# A terminal/process inside dms.service could be killed by its own
# restart. Require the switch to be launched from a separate cgroup/TTY.
if [[ -r "/proc/$BASHPID/cgroup" ]] &&
   grep -Fq "/dms.service" "/proc/$BASHPID/cgroup"; then
    echo "DMS_SWITCH_BLOCKED: run from a terminal outside the DMS service cgroup" >&2
    exit 1
fi
if [[ ! -t 0 ]]; then
    echo "DMS_SWITCH_BLOCKED: interactive terminal required" >&2
    exit 1
fi
printf '%s\n' "$preview_out"
printf 'WARNING: DMS and child plugins will be interrupted on restart.\n'
printf 'Automatic rollback after 10 minutes unless you confirm the new frontend.\n'
read -r -p 'Type ACTIVATE to continue: ' answer
if [[ "$answer" != ACTIVATE ]]; then
    echo "DMS_SWITCH_CANCELLED: no changes made"
    exit 1
fi

if [[ ! -e "$control" ]]; then mkdir -m 700 -- "$control"; fi
chmod 700 "$control"
if [[ -e "$persistent" ]]; then
    if [[ -L "$persistent" || ! -O "$persistent" ]] ||
       ! cmp -s -- "$0" "$persistent"; then
        echo "DMS_SWITCH_BLOCKED: persistent rollback controller differs" >&2
        exit 1
    fi
else
    install -m 700 -- "$0" "$persistent"
fi
if [[ -e "$marker" || -e "$dropin" ]] ||
   systemctl --user is-active --quiet "$timer"; then
    echo "DMS_SWITCH_BLOCKED: another override/rollback session is present" >&2
    exit 1
fi
if [[ ! -e "$dropdir" ]]; then mkdir -p -m 700 -- "$dropdir"; fi
if [[ -L "$dropdir" || ! -d "$dropdir" || ! -O "$dropdir" ]]; then
    echo "DMS_SWITCH_BLOCKED: unsafe systemd override directory" >&2
    exit 1
fi

tmp=$(mktemp -- "$dropdir/.50-chatgpt-private-qs.XXXXXXXX")
trap 'rm -f -- "$tmp"' EXIT
printf '[Service]\nEnvironment="PATH=%s:%s"\n' "$bin" "$live_path" > "$tmp"
chmod 600 "$tmp"
sha256sum "$tmp" | cut -d' ' -f1 > "$marker"
chmod 600 "$marker"

# Timed rollback is created FIRST, separately from the DMS cgroup.
if ! systemd-run --user --collect --on-active=10min \
    --unit="$timer_base" /usr/bin/bash "$persistent" --rollback; then
    rm -f -- "$marker"
    echo "DMS_SWITCH_BLOCKED: rollback timer creation failed" >&2
    exit 1
fi
if ! systemctl --user is-active --quiet "$timer"; then
    echo "DMS_SWITCH_BLOCKED: rollback timer not active" >&2
    exit 1
fi
# Atomic, no-clobber creation of the only managed systemd drop-in.
if ! ln -- "$tmp" "$dropin"; then
    echo "DMS_SWITCH_BLOCKED: override unexpectedly exists" >&2
    exit 1
fi
if ! systemctl --user daemon-reload; then
    echo "DMS_SWITCH_FAILED: daemon reload failed; rollback remains armed" >&2
    exit 1
fi
echo "DMS_SWITCH_RESTARTING: dms.service"
if ! systemctl --user restart dms.service; then
    echo "DMS_SWITCH_FAILED: startup failed; rollback remains armed" >&2
    exit 1
fi
echo "DMS_SWITCH_PENDING: candidate DMS service running"
echo "DMS_SWITCH_AUTOREVERT: after 10 minutes unless confirmed"
echo "DMS_SWITCH_CONFIRM: bash $persistent --confirm"
echo "DMS_SWITCH_ROLLBACK_NOW: bash $persistent --rollback"
