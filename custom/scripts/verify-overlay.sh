#!/usr/bin/env bash
# Verify rootfs overlay (files/) after materialize.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

fail=0
check_file() {
  local f="$1"
  if [[ -e "${ROOT}/files/${f}" ]]; then
    log "OK  files/${f}"
  else
    log "FAIL missing files/${f}"
    fail=1
  fi
}
check_grep() {
  local f="$1" pat="$2"
  if [[ -f "${ROOT}/files/${f}" ]] && grep -qE "${pat}" "${ROOT}/files/${f}"; then
    log "OK  files/${f} ~ ${pat}"
  else
    log "FAIL files/${f} missing or no match: ${pat}"
    fail=1
  fi
}
check_x() {
  local f="$1"
  if [[ -x "${ROOT}/files/${f}" ]]; then
    log "OK  executable files/${f}"
  else
    log "FAIL not executable: files/${f}"
    fail=1
  fi
}
check_absent() {
  local f="$1"
  if [[ -e "${ROOT}/files/${f}" ]]; then
    log "FAIL must not ship files/${f}"
    fail=1
  else
    log "OK  absent files/${f}"
  fi
}

info "Verify rootfs overlay"
[[ -d "${ROOT}/files" ]] || die "files/ missing — run prepare first"

check_x etc/uci-defaults/16_ensure_lan_dhcpv4
check_x etc/uci-defaults/96-dns-gateway-mode
check_x etc/uci-defaults/96-https-dns-resolver-fallback
check_x etc/uci-defaults/97-sqm-nss-optimize
check_x etc/uci-defaults/98-component-optimize
check_x etc/uci-defaults/98-disable-sqm-hotplug-race
check_x etc/uci-defaults/99-qol_nss_tailscale
check_x etc/uci-defaults/99-nss-perf-pins
check_x etc/uci-defaults/99-qol_wireless
check_x etc/init.d/tailscale
check_x etc/init.d/cloudflared
check_file etc/config/https-dns-proxy
check_file etc/config/cloudflared
check_file etc/config/sqm
check_file etc/rc.local
check_file etc/sysctl.d/60-cloudflared-ping.conf
check_file etc/sysctl.d/65-ram-opt.conf
check_file etc/sysctl.d/99-net-perf.conf
check_file usr/lib/sqm/nss-zk.qos
check_x etc/hotplug.d/iface/99-sqm-enabled
check_x etc/init.d/pstore-save
check_x usr/sbin/mem-watch.sh
check_grep etc/init.d/pstore-save 'pstore'
check_grep etc/uci-defaults/98-component-optimize 'pstore-save'
check_grep etc/uci-defaults/98-component-optimize 'mem-watch.sh'
check_grep etc/config/https-dns-proxy 'listen_port.*5053'
check_grep etc/config/https-dns-proxy 'resolver_url'
check_grep etc/uci-defaults/96-dns-gateway-mode '127.0.0.1#5053'
check_grep etc/uci-defaults/96-dns-gateway-mode 'https-dns-proxy'

# DNS rewrites: local feed package (custom/feed), selected via seed CONFIG_PACKAGE_*
if [[ -f "${CUSTOM_DIR}/feed/luci-app-dns-rewrites/Makefile" ]]; then
  log "OK  custom/feed/luci-app-dns-rewrites (feed)"
else
  log "FAIL missing custom/feed/luci-app-dns-rewrites"
  fail=$((fail + 1))
fi
if [[ -f "${CUSTOM_DIR}/feed/luci-app-wol-api/Makefile" ]]; then
  log "OK  custom/feed/luci-app-wol-api (feed)"
else
  log "FAIL missing custom/feed/luci-app-wol-api"
  fail=$((fail + 1))
fi
if grep -qE '^src-link[[:space:]]+custom_feed[[:space:]]+custom/feed' "${CUSTOM_DIR}/feeds.conf.append" 2>/dev/null; then
  log "OK  feeds.conf.append src-link custom_feed"
else
  log "FAIL feeds.conf.append missing src-link custom_feed"
  fail=$((fail + 1))
fi
check_absent etc/config/aykc_dns
check_absent usr/sbin/dns-rewrite-apply


# AGH must not ship in this DNS mode
check_absent etc/config/adguardhome
check_absent etc/adguardhome/filter-refresh.sh
check_absent etc/init.d/adguardhome-filters

check_grep etc/init.d/tailscale 'GOGC=10'
check_grep etc/init.d/tailscale 'GOMEMLIMIT'
check_grep etc/init.d/cloudflared 'GOGC=10'
check_grep etc/config/sqm 'nss-zk.qos'
check_grep etc/config/sqm "option enabled '0'"
check_grep usr/lib/sqm/nss-zk.qos 'interval 50ms'
check_grep usr/lib/sqm/nss-zk.qos 'keeping NSS modules loaded'
check_grep etc/sysctl.d/99-net-perf.conf 'nf_conntrack_max'
check_grep etc/uci-defaults/99-qol_nss_tailscale 'packet_steering'
check_grep etc/uci-defaults/99-qol_nss_tailscale 'skb_recycler'
check_grep etc/uci-defaults/99-nss-perf-pins 'packet_steering'
check_grep etc/uci-defaults/99-nss-perf-pins 'skb_recycler'
check_grep etc/config/https-dns-proxy 'cloudflare-dns.com'
# Must not tear down IFB (NSS act_nssmirred panic / reboot loop)
if grep -qE '^\s*\$IP link del \$DEV type ifb' "${ROOT}/files/usr/lib/sqm/nss-zk.qos" 2>/dev/null; then
  log "FAIL nss-zk.qos still deletes IFB (NSS panic risk)"
  fail=1
else
  log "OK  nss-zk.qos does not ip link del IFB"
fi
check_grep etc/init.d/pstore-save 'MAX_FILE_BYTES'
check_grep etc/uci-defaults/97-sqm-nss-optimize "enabled='0'"
# status-push is device-only (not in image)
check_absent etc/uci-defaults/94-status-push
check_absent usr/sbin/status-push.sh
check_grep etc/rc.local '^exit 0'
check_grep etc/sysctl.d/60-cloudflared-ping.conf 'ping_group_range'

# Safety: first-boot scripts must not rewrite WAN / invent DHCP (except 16_ and 96-dns)
for f in 97-sqm-nss-optimize 98-component-optimize 99-qol_nss_tailscale 99-nss-perf-pins 99-qol_wireless; do
  if grep -qE 'dhcp\.|network\.lan' "${ROOT}/files/etc/uci-defaults/${f}" 2>/dev/null; then
    log "FAIL ${f} must not touch dhcp/network.lan"
    fail=1
  else
    log "OK  ${f} no dhcp/lan rewrites"
  fi
done

[[ "${fail}" -eq 0 ]] || die "overlay verification failed"
info "Overlay OK"
