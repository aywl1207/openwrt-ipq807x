#!/usr/bin/env bash
# Compatibility wrapper → custom/scripts/apply-go-optimize.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${ROOT}/custom/scripts/apply-go-optimize.sh" "$@"
