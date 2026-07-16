#!/usr/bin/env bash
# Apply Tailscale Flash/RAM optimizations against the packages feed copy.
# Run AFTER: ./scripts/feeds update -a && ./scripts/feeds install -a
#
# Optimizations:
#   1) GO_PKG_LDFLAGS += -s -w  (strip symbols / DWARF)
#   2) procd env GOGC=10        (aggressive Go GC to reduce RAM)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS_DIR=""

# Prefer installed feed symlink target, then raw feeds tree
for candidate in \
  "${ROOT}/package/feeds/packages/tailscale" \
  "${ROOT}/feeds/packages/net/tailscale"
do
  if [[ -f "${candidate}/Makefile" ]]; then
    TS_DIR="${candidate}"
    break
  fi
done

if [[ -z "${TS_DIR}" ]]; then
  echo "ERROR: tailscale package not found."
  echo "  Run: ./scripts/feeds update -a && ./scripts/feeds install -a"
  echo "  Expected: feeds/packages/net/tailscale or package/feeds/packages/tailscale"
  exit 1
fi

echo "==> Optimizing Tailscale at: ${TS_DIR}"

# --- 1) Binary strip via GO_PKG_LDFLAGS -------------------------------------
MF="${TS_DIR}/Makefile"
if grep -q "GO_PKG_LDFLAGS:=-s -w" "${MF}" 2>/dev/null; then
  echo "    [Makefile] already has -s -w"
elif grep -q '^GO_PKG_LDFLAGS:=' "${MF}"; then
  # Prepend -s -w once if missing
  if grep -q 'GO_PKG_LDFLAGS:=.*-s -w' "${MF}"; then
    echo "    [Makefile] -s -w already present"
  else
    sed -i 's/^GO_PKG_LDFLAGS:=/GO_PKG_LDFLAGS:=-s -w /' "${MF}"
    echo "    [Makefile] injected GO_PKG_LDFLAGS -s -w"
  fi
else
  # Fallback insert after GO_PKG line
  sed -i "/^GO_PKG:=/a GO_PKG_LDFLAGS:=-s -w" "${MF}"
  echo "    [Makefile] added GO_PKG_LDFLAGS:=-s -w"
fi

# --- 2) GOGC=10 in init script ----------------------------------------------
INIT=""
for init_candidate in \
  "${TS_DIR}/files/tailscale.init" \
  "${TS_DIR}/files/etc/init.d/tailscale"
do
  if [[ -f "${init_candidate}" ]]; then
    INIT="${init_candidate}"
    break
  fi
done

if [[ -z "${INIT}" ]]; then
  echo "WARNING: tailscale.init not found under ${TS_DIR}/files — skip GOGC"
else
  if grep -q 'GOGC=10' "${INIT}"; then
    echo "    [init] GOGC=10 already present"
  else
    # Prefer modern procd_set_param env line with firewall mode
    if grep -q 'procd_set_param env TS_DEBUG_FIREWALL_MODE' "${INIT}"; then
      sed -i 's/procd_set_param env TS_DEBUG_FIREWALL_MODE="\$fw_mode"/procd_set_param env TS_DEBUG_FIREWALL_MODE="$fw_mode" GOGC=10/' "${INIT}"
      # Also append for robustness
      if ! grep -q 'procd_append_param env GOGC=10' "${INIT}"; then
        sed -i '/procd_set_param env TS_DEBUG_FIREWALL_MODE/a\  procd_append_param env GOGC=10' "${INIT}"
      fi
      echo "    [init] injected GOGC=10 into procd env"
    elif grep -q 'procd_set_param env' "${INIT}"; then
      sed -i '0,/procd_set_param env /s//procd_set_param env GOGC=10 /' "${INIT}"
      echo "    [init] injected GOGC=10 into existing procd env"
    else
      # Insert after procd_open_instance
      sed -i '/procd_open_instance/a\  procd_set_param env GOGC=10' "${INIT}"
      echo "    [init] added procd_set_param env GOGC=10"
    fi
  fi
fi

# --- 3) Mirror optimized init into files/ overlay (rootfs last-write wins) --
OVERLAY_INIT="${ROOT}/files/etc/init.d/tailscale"
mkdir -p "$(dirname "${OVERLAY_INIT}")"
if [[ -n "${INIT}" ]]; then
  cp -f "${INIT}" "${OVERLAY_INIT}"
  chmod 755 "${OVERLAY_INIT}"
  echo "    [overlay] synced -> files/etc/init.d/tailscale"
fi

echo "==> Done. Rebuild package with:"
echo "    make package/tailscale/{clean,compile} V=s"
echo "    # or full image: make -j\$(nproc) V=s"
