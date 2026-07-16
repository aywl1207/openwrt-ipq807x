#!/usr/bin/env bash
# Build OpenWrt firmware for QNAP QHora-301W only.
# Keeps clean_seed.config components (Tailscale, AdGuard, Cloudflare, Argon, NSS…).
#
# Usage:
#   ./scripts/build-qnap-301w.sh              # full build
#   ./scripts/build-qnap-301w.sh --config-only # stop after defconfig
#   ./scripts/build-qnap-301w.sh --download    # feeds + download only
#   JOBS=16 ./scripts/build-qnap-301w.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

JOBS="${JOBS:-$(nproc)}"
LOG_DIR="${ROOT}/logs"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="${LOG_DIR}/build-qnap-301w-${STAMP}.log"

MODE="full"
case "${1:-}" in
  --config-only) MODE="config" ;;
  --download)    MODE="download" ;;
  --help|-h)
    sed -n '2,12p' "$0"
    exit 0
    ;;
esac

exec > >(tee -a "${LOG}") 2>&1

echo "============================================================"
echo " QNAP 301W build  |  $(date -Is)  |  jobs=${JOBS}  |  mode=${MODE}"
echo " log: ${LOG}"
echo "============================================================"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing tool: $1"; exit 1; }; }
need make
need git
need python3
need wget
need rsync

# --- 0) Materialize rootfs overlay (tracked under custom/files; /files is gitignored)
echo "==> [0/6] materialize custom/files → files/"
if [[ -d custom/files ]]; then
  mkdir -p files
  rsync -a custom/files/ files/
  find files/etc/init.d files/etc/uci-defaults -type f -exec chmod +x {} \; 2>/dev/null || true
else
  echo "WARNING: custom/files missing — rootfs overlay may be incomplete"
fi
# Keep helper scripts in sync with custom/scripts mirrors when present
if [[ -d custom/scripts ]]; then
  install -m0755 custom/scripts/apply-tailscale-optimize.sh scripts/ 2>/dev/null || true
  install -m0755 custom/scripts/build-qnap-301w.sh scripts/ 2>/dev/null || true
fi

# --- 1) Feeds ----------------------------------------------------------------
echo "==> [1/6] feeds update / install"
# Ensure Tailscale notes exist on feeds.conf.default (idempotent)
if [[ -f custom/feeds.conf.append ]] && ! grep -q 'Tailscale VPN' feeds.conf.default 2>/dev/null; then
  cat custom/feeds.conf.append >> feeds.conf.default
fi
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install tailscale || true

# --- 2) Tailscale strip + GOGC -----------------------------------------------
echo "==> [2/6] Tailscale size/RAM optimize"
if [[ -x ./scripts/apply-tailscale-optimize.sh ]]; then
  ./scripts/apply-tailscale-optimize.sh
else
  echo "WARNING: apply-tailscale-optimize.sh missing; skip"
fi

# --- 3) Config stack ---------------------------------------------------------
echo "==> [3/6] merge .full_config + clean_seed + seed_qnap_301w"
[[ -f .full_config ]] || { echo "ERROR: .full_config missing"; exit 1; }
[[ -f clean_seed.config ]] || { echo "ERROR: clean_seed.config missing"; exit 1; }
[[ -f seed_qnap_301w.config ]] || { echo "ERROR: seed_qnap_301w.config missing"; exit 1; }

cp -f .full_config .config
cat clean_seed.config >> .config
cat seed_qnap_301w.config >> .config
# Optional extra seed (Tailscale/NSS fragment) — only if present & not redundant
if [[ -f seed_tailscale_nss.config ]]; then
  cat seed_tailscale_nss.config >> .config
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
check_y CONFIG_TARGET_qualcommax_ipq807x_DEVICE_qnap_301w
check_y CONFIG_PACKAGE_ipq-wifi-qnap_301w
check_y CONFIG_PACKAGE_kmod-fs-f2fs
check_y CONFIG_PACKAGE_kmod-qca-nss-drv
check_y CONFIG_PACKAGE_kmod-qca-nss-ecm
check_y CONFIG_PACKAGE_tailscale
check_y CONFIG_PACKAGE_adguardhome
check_y CONFIG_PACKAGE_cloudflared
check_y CONFIG_PACKAGE_luci-theme-argon
# multi-profile must be off for single-device
if grep -q '^CONFIG_TARGET_MULTI_PROFILE=y' .config; then
  echo "  WARN CONFIG_TARGET_MULTI_PROFILE still y (unexpected)"
fi
if grep -q '^CONFIG_IPQ_MEM_PROFILE_1024=y' .config || grep -q '^CONFIG_KERNEL_IPQ_MEM_PROFILE=1024' .config; then
  echo "  OK  IPQ mem profile 1024"
else
  echo "  WARN IPQ mem profile not 1024 — check .config"
  grep -E 'IPQ_MEM_PROFILE|KERNEL_IPQ_MEM' .config | head -10 || true
fi
[[ "${fail}" -eq 0 ]] || { echo "ERROR: config verification failed"; exit 1; }

# Persist a reproducible diffconfig snapshot
mkdir -p "${LOG_DIR}"
./scripts/diffconfig.sh > "${LOG_DIR}/diffconfig-qnap-301w-${STAMP}.config" || true
cp -f .config "${LOG_DIR}/fullconfig-qnap-301w-${STAMP}.config"

# Device uci-defaults perms
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
ls -lh bin/targets/qualcommax/ipq807x/*301w* 2>/dev/null || \
  ls -lh bin/targets/qualcommax/ipq807x/ | head -40
echo " Log: ${LOG}"
echo "============================================================"
