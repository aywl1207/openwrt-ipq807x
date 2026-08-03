#!/usr/bin/env bash
# Backward-compatible wrapper — full multi-component optimize lives in
# scripts/apply-component-optimize.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${ROOT}/scripts/apply-component-optimize.sh" "$@"
