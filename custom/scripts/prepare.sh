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
  # Ensure custom_feed is registered (absolute src-link)
  grep -qE '^src-link[[:space:]]+custom_feed[[:space:]]' feeds.conf.default \
    || die "feeds.conf.default missing src-link custom_feed after append_feeds_conf"
  ./scripts/feeds update -a
  # Local feed first so install -a sees luci-app-dns-rewrites
  ./scripts/feeds update custom_feed
  ./scripts/feeds install -a
  # Explicit installs (packages feed + local custom_feed)
  ./scripts/feeds install tailscale luci-app-tailscale-community cloudflared https-dns-proxy 2>/dev/null || true
  info "Install luci-app-dns-rewrites from custom_feed"
  if ! ./scripts/feeds install -p custom_feed luci-app-dns-rewrites; then
    ./scripts/feeds install luci-app-dns-rewrites \
      || die "feeds install luci-app-dns-rewrites failed (is custom_feed linked?)"
  fi
  # Must exist for CONFIG_PACKAGE_* to survive defconfig
  if [[ ! -f package/feeds/custom_feed/luci-app-dns-rewrites/Makefile ]] \
     && [[ ! -f feeds/custom_feed/luci-app-dns-rewrites/Makefile ]]; then
    die "luci-app-dns-rewrites not present after feeds install"
  fi
  log "OK luci-app-dns-rewrites feed package installed"
  info "Install luci-app-wol-api from custom_feed"
  if ! ./scripts/feeds install -p custom_feed luci-app-wol-api; then
    ./scripts/feeds install luci-app-wol-api \
      || die "feeds install luci-app-wol-api failed (is custom_feed linked?)"
  fi
  if [[ ! -f package/feeds/custom_feed/luci-app-wol-api/Makefile ]] \
     && [[ ! -f feeds/custom_feed/luci-app-wol-api/Makefile ]]; then
    die "luci-app-wol-api not present after feeds install"
  fi
  log "OK luci-app-wol-api feed package installed"
  info "Install udp-broadcast-relay-redux from custom_feed"
  if ! ./scripts/feeds install -p custom_feed udp-broadcast-relay-redux; then
    ./scripts/feeds install udp-broadcast-relay-redux \
      || die "feeds install udp-broadcast-relay-redux failed (is custom_feed linked?)"
  fi
  if [[ ! -f package/feeds/custom_feed/udp-broadcast-relay-redux/Makefile ]] \
     && [[ ! -f feeds/custom_feed/udp-broadcast-relay-redux/Makefile ]]; then
    die "udp-broadcast-relay-redux not present after feeds install"
  fi
  log "OK udp-broadcast-relay-redux feed package installed"
  ls -la package/feeds/custom_feed/ 2>/dev/null || ls -la feeds/custom_feed/ | head
  "${CUSTOM_SCRIPTS_DIR}/apply-go-optimize.sh"
  avahi_slot_patch="${CUSTOM_DIR}/patches/avahi/030-legacy-unicast-slots.patch"
  avahi_slot_dst="${ROOT}/feeds/packages/libs/avahi/patches/030-legacy-unicast-slots.patch"
  if [[ -f "${avahi_slot_patch}" && -d "$(dirname "${avahi_slot_dst}")" ]]; then
    cp -f "${avahi_slot_patch}" "${avahi_slot_dst}"
    log "OK avahi legacy-unicast slots patch (1024)"
  else
    die "avahi slots patch missing or avahi package not installed"
  fi
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
  force_device_rootfs_packages
  info "make defconfig (after force_device_rootfs_packages)"
  make defconfig
  "${CUSTOM_SCRIPTS_DIR}/verify-config.sh"
  "${CUSTOM_SCRIPTS_DIR}/verify-overlay.sh"
fi

info "prepare complete"
