#!/usr/bin/env bash
# Backup fork-owned paths listed in custom/PRESERVE.list
# Usage: ./custom/scripts/sync-backup.sh /tmp/openwrt-custom-backup
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

BACKUP="${1:-}"
[[ -n "${BACKUP}" ]] || die "usage: $0 <backup-dir>"

rm -rf "${BACKUP}"
mkdir -p "${BACKUP}"

LIST="${PRESERVE_LIST}"
if [[ ! -f "${LIST}" ]]; then
  warn "PRESERVE.list missing; using minimal fallback"
  LIST="${BACKUP}/PRESERVE.list.fallback"
  cat > "${LIST}" <<'EOF'
custom/
.github/workflows/build-ipq807x.yml
.github/workflows/sync-upstream.yml
README.md
EOF
fi

info "Preserving paths from ${LIST}"
while IFS= read -r raw || [[ -n "${raw}" ]]; do
  path="$(echo "${raw}" | sed 's/#.*//;s/[[:space:]]*$//;s/^[[:space:]]*//')"
  [[ -z "${path}" ]] && continue
  if [[ ! -e "${path}" ]]; then
    log "skip (missing): ${path}"
    continue
  fi
  log "backup: ${path}"
  mkdir -p "${BACKUP}/$(dirname "${path}")"
  if [[ -d "${path}" ]]; then
    rm -rf "${BACKUP}/${path}"
    cp -a "${path}" "${BACKUP}/${path}"
  else
    cp -a "${path}" "${BACKUP}/${path}"
  fi
done < "${LIST}"

cp -a "${LIST}" "${BACKUP}/PRESERVE.list.used" 2>/dev/null || true
log "Backup complete ($(find "${BACKUP}" -type f | wc -l) files)"
