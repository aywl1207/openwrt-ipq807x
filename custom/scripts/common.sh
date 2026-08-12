#!/usr/bin/env bash
# Shared helpers for fork tooling under custom/scripts/.
# shellcheck disable=SC2034
set -euo pipefail

# Resolve repo root from this file: custom/scripts/common.sh → ../..
CUSTOM_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(cd "${CUSTOM_SCRIPTS_DIR}/.." && pwd)"
ROOT="$(cd "${CUSTOM_DIR}/.." && pwd)"

CUSTOM_CONFIG_DIR="${CUSTOM_DIR}/config"
CUSTOM_FILES_DIR="${CUSTOM_DIR}/files"
CUSTOM_DOCS_DIR="${CUSTOM_DIR}/docs"

SEED_CLEAN="${CUSTOM_CONFIG_DIR}/clean_seed.config"
SEED_1G="${CUSTOM_CONFIG_DIR}/seed_ipq807x_1g.config"
REQUIRED_SYMBOLS="${CUSTOM_CONFIG_DIR}/required_symbols.txt"
FEEDS_APPEND="${CUSTOM_DIR}/feeds.conf.append"
UPSTREAM_SHA_FILE="${CUSTOM_DIR}/UPSTREAM_SHA"
PRESERVE_LIST="${CUSTOM_DIR}/PRESERVE.list"

# Stable marker for idempotent feeds append
FEEDS_MARKER_BEGIN="# BEGIN custom/feeds.conf.append"
FEEDS_MARKER_END="# END custom/feeds.conf.append"

log()  { printf '    %s\n' "$*"; }
info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

cd_root() {
  cd "${ROOT}"
}

# Materialize durable overlay → gitignored files/
materialize_overlay() {
  info "Materialize custom/files → files/"
  [[ -d "${CUSTOM_FILES_DIR}" ]] || die "missing overlay: ${CUSTOM_FILES_DIR}"
  mkdir -p "${ROOT}/files"
  # --delete drops removed overlay files (e.g. status-push no longer shipped)
  rsync -a --delete "${CUSTOM_FILES_DIR}/" "${ROOT}/files/"
  # Executable policy for OpenWrt hooks
  find "${ROOT}/files/etc/init.d" "${ROOT}/files/etc/uci-defaults" -type f \
    -exec chmod +x {} \; 2>/dev/null || true
  find "${ROOT}/files/etc/config" "${ROOT}/files/etc/sysctl.d" -type f \
    -exec chmod 644 {} \; 2>/dev/null || true
  if [[ -f "${ROOT}/files/usr/lib/sqm/nss-zk.qos" ]]; then
    chmod 755 "${ROOT}/files/usr/lib/sqm/nss-zk.qos" || true
  fi
  log "overlay files: $(find "${ROOT}/files" -type f | wc -l)"
}

# Idempotent refresh of custom feeds block in feeds.conf.default.
# Markers contain '/' so use awk fixed-string matching (not sed /…/).
# src-link paths must be absolute (OpenWrt requirement).
append_feeds_conf() {
  local feeds="${ROOT}/feeds.conf.default"
  local tmp feed_abs
  [[ -f "${FEEDS_APPEND}" ]] || { log "no feeds append file — skip"; return 0; }
  [[ -f "${feeds}" ]] || die "missing ${feeds}"
  feed_abs="${ROOT}/custom/feed"
  [[ -d "${feed_abs}" ]] || die "missing local feed dir: ${feed_abs}"

  if grep -qF "${FEEDS_MARKER_BEGIN}" "${feeds}" 2>/dev/null; then
    info "Refresh custom feeds block in feeds.conf.default"
  else
    info "Append custom feeds block → feeds.conf.default"
  fi

  tmp="$(mktemp)"
  # Drop any existing marker block, then re-append current feeds.conf.append
  awk -v b="${FEEDS_MARKER_BEGIN}" -v e="${FEEDS_MARKER_END}" '
    $0 == b { skip = 1; next }
    skip && $0 == e { skip = 0; next }
    !skip { print }
  ' "${feeds}" > "${tmp}"

  # Strip trailing empty lines before re-append
  sed -i -e :a -e '/^$/{$d;N;ba' -e '}' "${tmp}"

  {
    cat "${tmp}"
    printf '\n%s\n' "${FEEDS_MARKER_BEGIN}"
    # Comments from append file; always emit absolute src-link last
    sed -e '/./,$!d' -e '/^src-link[[:space:]]/d' "${FEEDS_APPEND}"
    printf 'src-link custom_feed %s\n' "${feed_abs}"
    printf '%s\n' "${FEEDS_MARKER_END}"
  } > "${feeds}"
  rm -f "${tmp}"
  log "feeds: custom_feed → ${feed_abs} (src-link)"
}

chmod_fork_scripts() {
  find "${CUSTOM_SCRIPTS_DIR}" -type f -name '*.sh' -exec chmod +x {} \;
  # Optional root wrappers
  for w in \
    "${ROOT}/scripts/build-ipq807x-1g.sh" \
    "${ROOT}/scripts/apply-component-optimize.sh" \
    "${ROOT}/scripts/apply-tailscale-optimize.sh"
  do
    [[ -f "$w" ]] && chmod +x "$w" || true
  done
}

require_seed_files() {
  [[ -f "${SEED_CLEAN}" ]] || die "missing ${SEED_CLEAN}"
  [[ -f "${SEED_1G}" ]] || die "missing ${SEED_1G}"
  [[ -f "${ROOT}/.full_config" ]] || die "missing ${ROOT}/.full_config (upstream base)"
}

# Merge config stack into .config (does not run defconfig)
merge_config_stack() {
  require_seed_files
  info "Merge .full_config + clean_seed + seed_ipq807x_1g"
  cp -f "${ROOT}/.full_config" "${ROOT}/.config"
  cat "${SEED_CLEAN}" >> "${ROOT}/.config"
  cat "${SEED_1G}" >> "${ROOT}/.config"
}

# After DEVICE pin + defconfig, OpenWrt may leave DEVICE_PACKAGES as =m and omit
# them from rootfs (caused RO overlay + missing ath11k board data on local build).
# Force critical packages =y and re-defconfig so they always land in the image.
force_device_rootfs_packages() {
  local cfg="${ROOT}/.config"
  [[ -f "${cfg}" ]] || die "force_device_rootfs_packages: missing .config"
  info "Force critical rootfs packages =y (DEVICE_PACKAGES + feed apps)"
  {
    echo
    echo '# --- force_device_rootfs_packages (custom/scripts) ---'
    # QNAP 301w Target-Profile-Packages (must be in squashfs, not =m only)
    echo 'CONFIG_PACKAGE_ipq-wifi-qnap_301w=y'
    echo 'CONFIG_PACKAGE_kmod-fs-f2fs=y'
    echo 'CONFIG_PACKAGE_f2fs-tools=y'
    echo 'CONFIG_PACKAGE_f2fsck=y'
    echo 'CONFIG_PACKAGE_mkf2fs=y'
    # Feed LuCI app (seed already sets these; re-assert post-defconfig)
    echo 'CONFIG_PACKAGE_luci-app-dns-rewrites=y'
    echo 'CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y'
    echo 'CONFIG_PACKAGE_luci-app-wol-api=y'
    echo 'CONFIG_PACKAGE_luci-i18n-wol-api-zh-tw=y'
    echo 'CONFIG_PACKAGE_etherwake=y'
    # NSS SQM deps
    echo 'CONFIG_PACKAGE_sqm-scripts=y'
    echo 'CONFIG_PACKAGE_sqm-scripts-nss=y'
    echo 'CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y'
    echo 'CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y'
    echo 'CONFIG_PACKAGE_nss-firmware-ipq807x=y'
    echo 'CONFIG_PACKAGE_nss-firmware=y'
  } >> "${cfg}"
}

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
