# Per-component optimizations (IPQ807x ~1GB)

Applied by `scripts/apply-component-optimize.sh` + `custom/files/` overlays.
All packages listed in the README remain installed; tuning is size/RAM/runtime only.

| Component | Flash / binary | RAM / runtime | Notes |
|-----------|----------------|---------------|--------|
| **tailscale** | `GO_PKG_LDFLAGS -s -w` | `GOGC=10`, `GOMEMLIMIT=128MiB` | Overlay init; service enabled on first boot |
| **adguardhome** | `GO_PKG_LDFLAGS -s -w` | UCI `gc=20`, `maxprocs=2`, `memlimit=192MiB` (bytes) | **Enabled on boot** — primary DNS provider for this fork |
| **cloudflared** | `GO_PKG_LDFLAGS -s -w` | `GOGC=10`, `GOMEMLIMIT=96MiB` | `enabled=0`; `loglevel=warn`; log on `/tmp` |
| **NSS / ECM** | firmware 12.5 + crypto | `pbuf=auto`; SW/HW flow offload **off** | Let ECM own acceleration |
| **sqm / sqm-nss** | — | service **disabled** until configured | Packages kept for on-demand use |
| **zram-swap** | — | `zram_size_mb=256`, `lzo-rle` | Upstream default ~½ RAM is too large with NSS |
| **haveged** | — | enabled early | Stock thresholds OK |
| **mdns-repeater** | — | default iface `br-lan` only | Dropped phantom `eth0.2` |
| **udp-broadcast-relay-redux** | — | no auto rules | Only runs when UCI instances defined |
| **drill / ipset / ddns** | normal strip | on-demand CLI | No daemon cost |
| **luci-theme-argon** | theme assets | LuCI only | No always-on daemon |
| **shadow-all** | larger rootfs | unused until login utils | Kept as requested; BusyBox covers most needs |

## Overlay map

```text
custom/files/
  etc/init.d/tailscale
  etc/init.d/cloudflared
  etc/config/adguardhome
  etc/config/cloudflared
  etc/config/mdns_repeater
  etc/sysctl.d/50-adguardhome.conf     # 2.5MB UDP buffers (was 7.5MB)
  etc/uci-defaults/16_ensure_lan_dhcpv4
  etc/uci-defaults/98-component-optimize
  etc/uci-defaults/99-qol_nss_tailscale
  etc/uci-defaults/99-qol_wireless
```

## Rebuild after feeds

```bash
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/apply-component-optimize.sh
# or full pipeline:
./scripts/build-ipq807x-1g.sh
```
