#!/usr/bin/env bash
# Apply per-component size/RAM optimizations for IPQ807x 1GB-class builds.
# Run AFTER: ./scripts/feeds update -a && ./scripts/feeds install -a
#
# Coverage:
#   - Go packages: tailscale, adguardhome, cloudflared → GO_PKG_LDFLAGS -s -w
#   - Rootfs overlays: custom/files → files/ (GOGC / GOMEMLIMIT / UCI defaults)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log() { echo "    $*"; }
section() { echo "==> $*"; }

find_pkg_dir() {
  local name="$1"
  local candidate
  for candidate in \
    "${ROOT}/package/feeds/packages/${name}" \
    "${ROOT}/feeds/packages/net/${name}" \
    "${ROOT}/feeds/packages/utils/${name}"
  do
    if [[ -f "${candidate}/Makefile" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done
  return 1
}

# Inject -s -w into GO_PKG_LDFLAGS (idempotent)
inject_go_strip() {
  local name="$1"
  local dir mf
  if ! dir="$(find_pkg_dir "${name}")"; then
    log "[${name}] SKIP — package not found (feeds install first?)"
    return 0
  fi
  mf="${dir}/Makefile"
  if grep -qE 'GO_PKG_LDFLAGS:=.*-s -w' "${mf}" 2>/dev/null; then
    log "[${name}] Makefile already has -s -w"
    return 0
  fi
  if grep -q '^GO_PKG_LDFLAGS:=' "${mf}"; then
    sed -i 's/^GO_PKG_LDFLAGS:=/GO_PKG_LDFLAGS:=-s -w /' "${mf}"
    log "[${name}] injected -s -w into existing GO_PKG_LDFLAGS"
  elif grep -q '^GO_PKG_LDFLAGS_X:=' "${mf}"; then
    sed -i '/^GO_PKG_LDFLAGS_X:=/i GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS:=-s -w before LDFLAGS_X"
  elif grep -q '^GO_PKG:=' "${mf}"; then
    sed -i '/^GO_PKG:=/a GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS:=-s -w after GO_PKG"
  else
    sed -i '/golang-package.mk/i GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS:=-s -w before golang-package.mk"
  fi
  if ! grep -qE 'GO_PKG_LDFLAGS:=.*-s -w' "${mf}"; then
    echo "ERROR: failed to inject -s -w into ${mf}" >&2
    exit 1
  fi
}

# Best-effort: inject GOGC into package init if missing (overlay still authoritative)
inject_feed_gogc() {
  local name="$1"
  local dir init
  if ! dir="$(find_pkg_dir "${name}")"; then
    return 0
  fi
  init=""
  for candidate in \
    "${dir}/files/${name}.init" \
    "${dir}/files/${name}" \
    "${dir}/files/etc/init.d/${name}"
  do
    if [[ -f "${candidate}" ]]; then
      init="${candidate}"
      break
    fi
  done
  # tailscale uses tailscale.init
  if [[ -z "${init}" ]]; then
    for candidate in "${dir}/files/"*.init; do
      if [[ -f "${candidate}" ]]; then
        init="${candidate}"
        break
      fi
    done
  fi
  [[ -n "${init}" ]] || return 0
  if grep -q 'GOGC=10' "${init}"; then
    log "[${name}] feed-init already has GOGC=10"
    return 0
  fi
  if grep -q 'procd_open_instance' "${init}"; then
    sed -i '/procd_open_instance/a\  procd_append_param env GOGC=10' "${init}"
    log "[${name}] feed-init: injected GOGC=10"
  else
    log "[${name}] feed-init: no procd_open_instance — skip"
  fi
}

materialize_overlay() {
  section "Materialize custom/files → files/"
  if [[ ! -d "${ROOT}/custom/files" ]]; then
    echo "ERROR: missing ${ROOT}/custom/files" >&2
    exit 1
  fi
  mkdir -p "${ROOT}/files"
  rsync -a "${ROOT}/custom/files/" "${ROOT}/files/"
  find "${ROOT}/files/etc/init.d" "${ROOT}/files/etc/uci-defaults" -type f \
    -exec chmod +x {} \; 2>/dev/null || true
  # config/sysctl not executable
  find "${ROOT}/files/etc/config" "${ROOT}/files/etc/sysctl.d" -type f \
    -exec chmod 644 {} \; 2>/dev/null || true
  log "overlay files:"
  find "${ROOT}/files" -type f | sort | sed 's/^/      /'
}

verify_overlays() {
  section "Verify critical overlay content"
  local fail=0
  check_grep() {
    local file="$1" pat="$2"
    if [[ -f "${ROOT}/${file}" ]] && grep -qE "${pat}" "${ROOT}/${file}"; then
      log "OK  ${file} ~ ${pat}"
    else
      log "FAIL ${file} missing or no match: ${pat}"
      fail=1
    fi
  }
  check_grep files/etc/init.d/tailscale 'GOGC=10'
  check_grep files/etc/init.d/tailscale 'GOMEMLIMIT'
  check_grep files/etc/init.d/cloudflared 'GOGC=10'
  check_grep files/etc/config/adguardhome "option gc '20'"
  check_grep files/etc/config/adguardhome "option memlimit "
  check_grep files/etc/uci-defaults/98-component-optimize 'zram_size_mb'
  # AdGuard Home is primary DNS — must be enabled on first boot
  check_grep files/etc/uci-defaults/98-component-optimize 'adguardhome enable'
  # NSS SQM path
  check_grep files/etc/config/sqm 'nss-zk.qos'
  check_grep files/usr/lib/sqm/nss-zk.qos 'interval 50ms'
  check_grep files/usr/lib/sqm/nss-zk.qos 'leaving qca_nss_qdisc'
  check_grep files/etc/uci-defaults/97-sqm-nss-optimize 'nss-zk.qos'
  [[ "${fail}" -eq 0 ]] || { echo "ERROR: overlay verification failed" >&2; exit 1; }
}

# --- main --------------------------------------------------------------------
section "Go binary strip (-s -w)"
for pkg in tailscale adguardhome cloudflared; do
  inject_go_strip "${pkg}"
done

section "Feed init GOGC fallback (best-effort)"
for pkg in tailscale cloudflared; do
  inject_feed_gogc "${pkg}"
done
# adguardhome uses UCI gc= — skip feed init patch (overlay config sets it)

materialize_overlay
verify_overlays

echo "==> Component optimize done."
echo "    Rebuild heavy packages or full image, e.g.:"
echo "      make package/feeds/packages/tailscale/{clean,compile} V=s"
echo "      make package/feeds/packages/adguardhome/{clean,compile} V=s"
echo "      make package/feeds/packages/cloudflared/{clean,compile} V=s"
echo "      make -j\$(nproc) V=s"
