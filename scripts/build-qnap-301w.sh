#!/usr/bin/env bash
# Compatibility wrapper — prefer: ./scripts/build-ipq807x-1g.sh
# Pins QNAP 301W as a single device on the shared 1GB IPQ807x seed.
echo "NOTE: build-qnap-301w.sh is deprecated; using build-ipq807x-1g.sh with DEVICE=qnap_301w" >&2
export DEVICE="${DEVICE:-qnap_301w}"
exec "$(cd "$(dirname "$0")" && pwd)/build-ipq807x-1g.sh" "$@"
