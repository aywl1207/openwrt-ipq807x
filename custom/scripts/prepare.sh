#!/usr/bin/env bash
# One-shot fork prepare: overlay, feeds append, optional feeds+go optimize.
#
# Usage:
#   ./custom/scripts/prepare.sh              # overlay + feeds append only
#   ./custom/scripts/prepare.sh --feeds      # + feeds update/install + go strip
#   ./custom/scripts/prepare.sh --config     # + merge seeds + make defconfig + verify
#
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

DO_FEEDS=0
DO_CONFIG=0
for arg in "$@"; do
  case "${arg}" in
    --feeds)  DO_FEEDS=1 ;;
    --config) DO_CONFIG=1; DO_FEEDS=1 ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) die "unknown arg: ${arg}" ;;
  esac
done

need_cmd rsync
chmod_fork_scripts
materialize_overlay
append_feeds_conf

if [[ "${DO_FEEDS}" -eq 1 ]]; then
  need_cmd make
  info "feeds update / install"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  ./scripts/feeds install tailscale luci-app-tailscale-community cloudflared https-dns-proxy 2>/dev/null || true
  "${CUSTOM_SCRIPTS_DIR}/apply-go-optimize.sh"
else
  # Still verify overlay without touching feeds tree
  "${CUSTOM_SCRIPTS_DIR}/verify-overlay.sh"
fi

if [[ "${DO_CONFIG}" -eq 1 ]]; then
  merge_config_stack
  if [[ -n "${DEVICE:-}" ]]; then
    info "Pin single device: ${DEVICE}"
    {
      echo '# CONFIG_TARGET_MULTI_PROFILE is not set'
      echo '# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set'
      echo "CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${DEVICE}=y"
    } >> "${ROOT}/.config"
  fi
  info "make defconfig"
  make defconfig
  "${CUSTOM_SCRIPTS_DIR}/verify-config.sh"
fi

info "prepare complete"
