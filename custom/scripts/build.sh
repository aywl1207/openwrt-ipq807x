#!/usr/bin/env bash
# Full IPQ807x 1GB-class firmware build (fork entrypoint).
#
# Usage:
#   ./custom/scripts/build.sh
#   ./custom/scripts/build.sh --config-only
#   ./custom/scripts/build.sh --download
#   DEVICE=dynalink_dl-wrx36 ./custom/scripts/build.sh
#   JOBS=16 ./custom/scripts/build.sh
#
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

JOBS="${JOBS:-$(nproc)}"
DEVICE="${DEVICE:-}"
LOG_DIR="${ROOT}/logs"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="${LOG_DIR}/build-ipq807x-${STAMP}.log"

MODE="full"
case "${1:-}" in
  --config-only) MODE="config" ;;
  --download)    MODE="download" ;;
  --help|-h)
    sed -n '2,14p' "$0"
    exit 0
    ;;
  "") ;;
  *) die "unknown arg: $1 (try --help)" ;;
esac

need_cmd make
need_cmd git
need_cmd python3
need_cmd wget
need_cmd rsync

exec > >(tee -a "${LOG}") 2>&1

echo "============================================================"
echo " IPQ807x 1GB build  |  $(date -Is)  |  jobs=${JOBS}  |  mode=${MODE}"
echo " DEVICE=${DEVICE:-<multi-profile from .full_config>}"
echo " log: ${LOG}"
echo "============================================================"

info "[1/5] prepare (feeds + go optimize + overlay)"
export DEVICE
"${CUSTOM_SCRIPTS_DIR}/prepare.sh" --feeds

info "[2/5] config stack + defconfig"
merge_config_stack
if [[ -n "${DEVICE}" ]]; then
  {
    echo '# CONFIG_TARGET_MULTI_PROFILE is not set'
    echo '# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set'
    echo "CONFIG_TARGET_qualcommax_ipq807x_DEVICE_${DEVICE}=y"
  } >> "${ROOT}/.config"
fi
make defconfig
force_device_rootfs_packages
make defconfig
"${CUSTOM_SCRIPTS_DIR}/verify-config.sh"
"${CUSTOM_SCRIPTS_DIR}/verify-overlay.sh"

./scripts/diffconfig.sh > "${LOG_DIR}/diffconfig-${STAMP}.config" || true
cp -f .config "${LOG_DIR}/fullconfig-${STAMP}.config"

if [[ "${MODE}" == "config" ]]; then
  info "config-only done. Edit with: make menuconfig"
  exit 0
fi

info "[3/5] make download (-j${JOBS})"
make download -j"${JOBS}" V=s || make download -j1 V=s

if [[ "${MODE}" == "download" ]]; then
  info "download-only done"
  exit 0
fi

info "[4/5] tools + toolchain"
make tools/install -j"${JOBS}" V=s || make tools/install -j1 V=s
make toolchain/install -j"${JOBS}" V=s || make toolchain/install -j1 V=s

info "[5/5] make world (-j${JOBS})"
if ! make -j"${JOBS}" V=s; then
  warn "Parallel build failed; retrying -j1 for a clear error..."
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
