#!/usr/bin/env bash
# Strip Go packages (-s -w) and re-materialize overlays.
# Run AFTER: feeds update/install
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
cd_root

inject_go_strip() {
  local name="$1" dir mf
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
    log "[${name}] injected -s -w into GO_PKG_LDFLAGS"
  elif grep -q '^GO_PKG_LDFLAGS_X:=' "${mf}"; then
    sed -i '/^GO_PKG_LDFLAGS_X:=/i GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS before LDFLAGS_X"
  elif grep -q '^GO_PKG:=' "${mf}"; then
    sed -i '/^GO_PKG:=/a GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS after GO_PKG"
  else
    sed -i '/golang-package.mk/i GO_PKG_LDFLAGS:=-s -w' "${mf}"
    log "[${name}] added GO_PKG_LDFLAGS before golang-package.mk"
  fi
  grep -qE 'GO_PKG_LDFLAGS:=.*-s -w' "${mf}" || die "failed to inject -s -w into ${mf}"
}

inject_feed_gogc() {
  local name="$1" dir init candidate
  if ! dir="$(find_pkg_dir "${name}")"; then
    return 0
  fi
  init=""
  for candidate in \
    "${dir}/files/${name}.init" \
    "${dir}/files/etc/init.d/${name}" \
    "${dir}/files/"*.init
  do
    if [[ -f "${candidate}" ]]; then
      init="${candidate}"
      break
    fi
  done
  [[ -n "${init}" ]] || return 0
  if grep -q 'GOGC=10' "${init}"; then
    log "[${name}] feed-init already has GOGC=10"
    return 0
  fi
  if grep -q 'procd_open_instance' "${init}"; then
    sed -i '/procd_open_instance/a\  procd_append_param env GOGC=10' "${init}"
    log "[${name}] feed-init: injected GOGC=10"
  fi
}

info "Go binary strip (-s -w)"
for pkg in tailscale adguardhome cloudflared; do
  inject_go_strip "${pkg}"
done

info "Feed init GOGC fallback"
for pkg in tailscale cloudflared; do
  inject_feed_gogc "${pkg}"
done

materialize_overlay
"${CUSTOM_SCRIPTS_DIR}/verify-overlay.sh"

info "Go optimize done"
