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

# Link/copy custom OpenWrt packages into package/custom/ (seed-selectable)
materialize_packages() {
  local src="${CUSTOM_DIR}/package"
  local dst="${ROOT}/package/custom"
  if [[ ! -d "${src}" ]]; then
    log "no custom/package — skip"
    return 0
  fi
  info "Materialize custom/package → package/custom"
  mkdir -p "${dst}"
  rsync -a --delete "${src}/" "${dst}/"
  # ensure executable helpers in package files/
  find "${dst}" -type f \( -name '*.init' -o -name 'dns-rewrite-apply' -o -path '*/files/95-*' \) -exec chmod +x {} \; 2>/dev/null || true
  log "custom packages: $(find "${dst}" -name Makefile | wc -l)"
}

materialize_overlay() {
  info "Materialize custom/files → files/"
  [[ -d "${CUSTOM_FILES_DIR}" ]] || die "missing overlay: ${CUSTOM_FILES_DIR}"
  mkdir -p "${ROOT}/files"
  rsync -a "${CUSTOM_FILES_DIR}/" "${ROOT}/files/"
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

# Idempotent feeds.conf.default append from custom/feeds.conf.append
append_feeds_conf() {
  local feeds="${ROOT}/feeds.conf.default"
  [[ -f "${FEEDS_APPEND}" ]] || { log "no feeds append file — skip"; return 0; }
  [[ -f "${feeds}" ]] || die "missing ${feeds}"

  if grep -qF "${FEEDS_MARKER_BEGIN}" "${feeds}" 2>/dev/null; then
    log "feeds.conf.default already has custom append block"
    return 0
  fi

  info "Append custom/feeds.conf.append → feeds.conf.default"
  {
    printf '\n%s\n' "${FEEDS_MARKER_BEGIN}"
    # strip leading blank lines from append file
    sed '/./,$!d' "${FEEDS_APPEND}"
    printf '%s\n' "${FEEDS_MARKER_END}"
  } >> "${feeds}"
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
