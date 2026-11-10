#!/usr/bin/env bash
# Opens chatgpt.com directly; never touches authentication tokens.
set -euo pipefail

MODE="${1:-isolated}"
THEME="${2:-1}"
URL="https://chatgpt.com/"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dms-chatgpt"
PROFILE="$DATA_DIR/zen-profile"

find_zen() {
    local exe
    for exe in zen-browser zen zen-browser-bin; do
        if command -v "$exe" >/dev/null 2>&1; then
            command -v "$exe"
            return 0
        fi
    done
    return 1
}

case "$MODE" in
    isolated)
        ZEN="$(find_zen)" || { echo "Zen Browser nicht gefunden (zen-browser/zen/zen-browser-bin)." >&2; exit 127; }
        mkdir -p "$PROFILE/chrome"
        if [[ "$THEME" == "1" ]]; then
            if ! command -v python3 >/dev/null 2>&1; then
                echo "Python 3 für DMS-CSS-Generierung benötigt." >&2
                exit 127
            fi
            python3 "$SCRIPT_DIR/theme_sync.py" "$PROFILE"
        fi
        # The isolated profile deliberately has its own login/session.
        # Do not touch the user's ordinary Zen profile.
        nohup env MOZ_ENABLE_WAYLAND=1 "$ZEN" --no-remote --profile "$PROFILE" --new-window "$URL" >/dev/null 2>&1 </dev/null &
        ;;
    existing)
        ZEN="$(find_zen)" || { echo "Zen Browser nicht gefunden." >&2; exit 127; }
        nohup env MOZ_ENABLE_WAYLAND=1 "$ZEN" --new-window "$URL" >/dev/null 2>&1 </dev/null &
        ;;
    system)
        command -v xdg-open >/dev/null 2>&1 || { echo "xdg-open nicht gefunden." >&2; exit 127; }
        nohup xdg-open "$URL" >/dev/null 2>&1 </dev/null &
        ;;
    *)
        echo "Unbekannter Browsermodus: $MODE" >&2
        exit 64
        ;;
esac
# A successful exit means the launch was requested, not that login succeeded.
