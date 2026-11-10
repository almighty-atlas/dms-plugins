#!/usr/bin/env bash
# Kept as a stable entry point for existing installations; all logic is tested Python.
set -euo pipefail
exec /usr/bin/env python3 "$(dirname -- "${BASH_SOURCE[0]}")/launcher.py" "$@"
