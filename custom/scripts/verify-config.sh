#!/usr/bin/env bash
# Verify .config symbols after make defconfig.
# Optional: DEVICE=foo_board also checks DEVICE_...=y
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

CFG="${ROOT}/.config"
[[ -f "${CFG}" ]] || die ".config missing — merge + defconfig first"
[[ -f "${REQUIRED_SYMBOLS}" ]] || die "missing ${REQUIRED_SYMBOLS}"

fail=0
info "Verify required Kconfig symbols"

while IFS= read -r raw || [[ -n "${raw}" ]]; do
  sym="$(echo "${raw}" | sed 's/#.*//;s/[[:space:]]//g')"
  [[ -z "${sym}" ]] && continue
  if grep -q "^${sym}=y$" "${CFG}"; then
    log "OK  ${sym}=y"
  else
    log "FAIL ${sym} not =y"
    grep -E "${sym}" "${CFG}" | head -3 || true
    fail=1
  fi
done < "${REQUIRED_SYMBOLS}"

# Memory profile (1GB class)
if grep -qE '^CONFIG_IPQ_MEM_PROFILE_1024=y$|^CONFIG_KERNEL_IPQ_MEM_PROFILE=1024$' "${CFG}"; then
  log "OK  IPQ mem profile 1024"
else
  log "WARN IPQ mem profile not 1024"
  grep -E 'IPQ_MEM_PROFILE|KERNEL_IPQ_MEM' "${CFG}" | head -8 || true
fi

if grep -q '^CONFIG_NSS_MEM_PROFILE_HIGH=y$' "${CFG}"; then
  log "OK  NSS_MEM_PROFILE_HIGH"
else
  log "WARN NSS mem profile not HIGH"
fi

if grep -q '^CONFIG_ATH11K_NSS_SUPPORT=y$' "${CFG}"; then
  log "OK  ATH11K_NSS_SUPPORT"
else
  log "WARN ATH11K_NSS_SUPPORT not set"
fi

if [[ -n "${DEVICE:-}" ]]; then
  dsym="CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${DEVICE}"
  if grep -q "^${dsym}=y$" "${CFG}"; then
    log "OK  ${dsym}=y"
  else
    log "FAIL ${dsym} not =y"
    fail=1
  fi
fi

# Re-check critical packages are not left as =m only
for s in \
  CONFIG_PACKAGE_ipq-wifi-qnap_301w \
  CONFIG_PACKAGE_kmod-fs-f2fs \
  CONFIG_PACKAGE_f2fs-tools \
  CONFIG_PACKAGE_luci-app-dns-rewrites
do
  if grep -q "^${s}=y$" "${CFG}"; then
    log "OK  ${s}=y (not modular-only)"
  elif grep -q "^${s}=m$" "${CFG}"; then
    log "FAIL ${s}=m (must be =y for image rootfs)"
    fail=1
  else
    log "FAIL ${s} missing"
    fail=1
  fi
done

[[ "${fail}" -eq 0 ]] || die "config verification failed"
info "Config OK"
