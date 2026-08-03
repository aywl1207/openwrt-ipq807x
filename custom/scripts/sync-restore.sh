#!/usr/bin/env bash
# Restore fork-owned paths after git reset to upstream.
# Usage: ./custom/scripts/sync-restore.sh /tmp/openwrt-custom-backup
# Expects /tmp/new_upstream_sha if present (written by sync workflow).
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

BACKUP="${1:-}"
[[ -n "${BACKUP}" && -d "${BACKUP}" ]] || die "usage: $0 <backup-dir>"

LIST="${BACKUP}/PRESERVE.list.used"
[[ -f "${LIST}" ]] || LIST="${PRESERVE_LIST}"

# Restore custom/ first so PRESERVE helpers exist
if [[ -d "${BACKUP}/custom" ]]; then
  rm -rf "${ROOT}/custom"
  cp -a "${BACKUP}/custom" "${ROOT}/custom"
  log "Restored custom/"
fi

# Re-source paths after restore (in case list location moved)
# shellcheck source=common.sh
source "${ROOT}/custom/scripts/common.sh"

while IFS= read -r raw || [[ -n "${raw}" ]]; do
  path="$(echo "${raw}" | sed 's/#.*//;s/[[:space:]]*$//;s/^[[:space:]]*//')"
  [[ -z "${path}" ]] && continue
  [[ "${path}" == "custom/" || "${path}" == "custom" ]] && continue
  if [[ ! -e "${BACKUP}/${path}" ]]; then
    log "skip restore (not in backup): ${path}"
    continue
  fi
  log "restore: ${path}"
  mkdir -p "$(dirname "${path}")"
  if [[ -d "${BACKUP}/${path}" ]]; then
    rm -rf "${path}"
    cp -a "${BACKUP}/${path}" "${path}"
  else
    cp -a "${BACKUP}/${path}" "${path}"
  fi
done < "${LIST}"

# Record upstream tip
if [[ -f /tmp/new_upstream_sha ]]; then
  mkdir -p "${CUSTOM_DIR}"
  cp /tmp/new_upstream_sha "${UPSTREAM_SHA_FILE}"
  log "Recorded UPSTREAM_SHA=$(cat "${UPSTREAM_SHA_FILE}")"
fi

chmod_fork_scripts
materialize_overlay
append_feeds_conf

# Critical path checks
for f in \
  custom/config/clean_seed.config \
  custom/config/seed_ipq807x_1g.config \
  custom/scripts/prepare.sh \
  custom/scripts/build.sh \
  custom/PRESERVE.list
do
  [[ -e "${ROOT}/${f}" ]] || die "missing after restore: ${f}"
done

info "Restore complete"
