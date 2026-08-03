#!/usr/bin/env bash
# Build OpenWrt firmware for IPQ807x 1GB-class routers (multi-device by default).
# Keeps clean_seed.config components (Tailscale, AdGuard, Cloudflare, Argon, NSS…).
#
# Usage:
#   ./scripts/build-ipq807x-1g.sh                 # multi-profile + 1G seed
#   ./scripts/build-ipq807x-1g.sh --config-only
#   ./scripts/build-ipq807x-1g.sh --download
#   DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh   # optional single device
#   JOBS=16 ./scripts/build-ipq807x-1g.sh
#
# DEVICE value is the OpenWrt device suffix, e.g.:
#   qnap_301w, dynalink_dl-wrx36, xiaomi_ax3600, linksys_mx4300, ...
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

JOBS="${JOBS:-$(nproc)}"
DEVICE="${DEVICE:-}"
LOG_DIR="${ROOT}/logs"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="${LOG_DIR}/build-ipq807x-1g-${STAMP}.log"

MODE="full"
case "${1:-}" in
  --config-only) MODE="config" ;;
  --download)    MODE="download" ;;
  --help|-h)
    sed -n '2,16p' "$0"
    exit 0
    ;;
esac

exec > >(tee -a "${LOG}") 2>&1

echo "============================================================"
echo " IPQ807x 1GB build  |  $(date -Is)  |  jobs=${JOBS}  |  mode=${MODE}"
echo " DEVICE=${DEVICE:-<multi-profile from .full_config>}"
echo " log: ${LOG}"
echo "============================================================"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing tool: $1"; exit 1; }; }
need make
need git
need python3
need wget
need rsync

# --- 0) Materialize rootfs overlay -------------------------------------------
echo "==> [0/6] materialize custom/files → files/"
if [[ -d custom/files ]]; then
  mkdir -p files
  rsync -a custom/files/ files/
  find files/etc/init.d files/etc/uci-defaults -type f -exec chmod +x {} \; 2>/dev/null || true
else
  echo "WARNING: custom/files missing — rootfs overlay may be incomplete"
fi

# --- 1) Feeds ----------------------------------------------------------------
echo "==> [1/6] feeds update / install"
if [[ -f custom/feeds.conf.append ]] && ! grep -q 'Tailscale VPN' feeds.conf.default 2>/dev/null; then
  cat custom/feeds.conf.append >> feeds.conf.default
fi
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install tailscale || true

# --- 2) Per-component strip + RAM overlays -----------------------------------
echo "==> [2/6] component optimize (Go strip + overlays)"
if [[ -x ./scripts/apply-component-optimize.sh ]]; then
  ./scripts/apply-component-optimize.sh
elif [[ -x ./scripts/apply-tailscale-optimize.sh ]]; then
  ./scripts/apply-tailscale-optimize.sh
else
  echo "WARNING: apply-component-optimize.sh missing; skip"
fi

# --- 3) Config stack ---------------------------------------------------------
echo "==> [3/6] merge .full_config + clean_seed + seed_ipq807x_1g"
[[ -f .full_config ]] || { echo "ERROR: .full_config missing"; exit 1; }
[[ -f clean_seed.config ]] || { echo "ERROR: clean_seed.config missing"; exit 1; }
[[ -f seed_ipq807x_1g.config ]] || { echo "ERROR: seed_ipq807x_1g.config missing"; exit 1; }

cp -f .full_config .config
cat clean_seed.config >> .config
cat seed_ipq807x_1g.config >> .config

# Optional: pin one device (faster local builds / single firmware)
if [[ -n "${DEVICE}" ]]; then
  echo "==> pinning single device: ${DEVICE}"
  {
    echo '# CONFIG_TARGET_MULTI_PROFILE is not set'
    echo '# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set'
    echo "CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${DEVICE}=y"
  } >> .config
fi

make defconfig

echo "==> verify critical symbols"
fail=0
check_y() {
  local k="$1"
  if grep -q "^${k}=y" .config; then
    echo "  OK  ${k}=y"
  else
    echo "  FAIL ${k} not =y"
    grep -E "${k}" .config | head -5 || true
    fail=1
  fi
}
check_y CONFIG_TARGET_qualcommax_ipq807x
check_y CONFIG_PACKAGE_kmod-qca-nss-drv
check_y CONFIG_PACKAGE_kmod-qca-nss-ecm
check_y CONFIG_PACKAGE_kmod-qca-nss-crypto
check_y CONFIG_PACKAGE_nss-eip-firmware
check_y CONFIG_PACKAGE_tailscale
check_y CONFIG_PACKAGE_adguardhome
check_y CONFIG_PACKAGE_cloudflared
check_y CONFIG_PACKAGE_luci-theme-argon
check_y CONFIG_PACKAGE_zram-swap
check_y CONFIG_PACKAGE_sqm-scripts-nss
if [[ -n "${DEVICE}" ]]; then
  check_y "CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${DEVICE}"
fi
if grep -q '^CONFIG_IPQ_MEM_PROFILE_1024=y' .config || grep -q '^CONFIG_KERNEL_IPQ_MEM_PROFILE=1024' .config; then
  echo "  OK  IPQ mem profile 1024 (1GB class)"
else
  echo "  WARN IPQ mem profile not 1024 — check .config"
  grep -E 'IPQ_MEM_PROFILE|KERNEL_IPQ_MEM' .config | head -10 || true
fi
if grep -q '^CONFIG_NSS_MEM_PROFILE_HIGH=y' .config; then
  echo "  OK  NSS_MEM_PROFILE_HIGH"
else
  echo "  WARN NSS mem profile not HIGH"
fi
if grep -q '^CONFIG_ATH11K_NSS_SUPPORT=y' .config; then
  echo "  OK  ATH11K_NSS_SUPPORT"
else
  echo "  WARN ATH11K_NSS_SUPPORT not set"
fi
[[ "${fail}" -eq 0 ]] || { echo "ERROR: config verification failed"; exit 1; }

mkdir -p "${LOG_DIR}"
./scripts/diffconfig.sh > "${LOG_DIR}/diffconfig-ipq807x-1g-${STAMP}.config" || true
cp -f .config "${LOG_DIR}/fullconfig-ipq807x-1g-${STAMP}.config"

chmod +x files/etc/uci-defaults/* 2>/dev/null || true
chmod +x files/etc/init.d/tailscale 2>/dev/null || true

if [[ "${MODE}" == "config" ]]; then
  echo "==> config-only done. Edit with: make menuconfig"
  exit 0
fi

# --- 4) Download -------------------------------------------------------------
echo "==> [4/6] make download (-j${JOBS})"
make download -j"${JOBS}" V=s || make download -j1 V=s

if [[ "${MODE}" == "download" ]]; then
  echo "==> download-only done"
  exit 0
fi

# --- 5) Tools + toolchain ----------------------------------------------------
echo "==> [5/6] tools + toolchain"
make tools/install -j"${JOBS}" V=s || make tools/install -j1 V=s
make toolchain/install -j"${JOBS}" V=s || make toolchain/install -j1 V=s

# --- 6) World build ----------------------------------------------------------
echo "==> [6/6] make world (-j${JOBS})"
if ! make -j"${JOBS}" V=s; then
  echo "Parallel build failed; retrying single-threaded for a clear error..."
  make -j1 V=s
fi

echo "============================================================"
echo " BUILD OK  $(date -Is)"
echo " Images:"
if [[ -n "${DEVICE}" ]]; then
  ls -lh "bin/targets/qualcommax/ipq807x/"*"${DEVICE}"* 2>/dev/null || \
    ls -lh bin/targets/qualcommax/ipq807x/ | head -40
else
  ls -lh bin/targets/qualcommax/ipq807x/ | head -60
fi
echo " Log: ${LOG}"
echo "============================================================"
