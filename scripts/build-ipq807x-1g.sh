#!/usr/bin/env bash
# Compatibility wrapper — canonical entrypoint is custom/scripts/build.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${ROOT}/custom/scripts/build.sh" "$@"
