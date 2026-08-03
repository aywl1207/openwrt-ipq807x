# Per-component optimizations (IPQ807x ~1GB)

Applied by `custom/scripts/apply-go-optimize.sh` + `custom/files/` overlays.
Packages listed in the README remain installed; tuning is size/RAM/runtime only.

| Component | Flash / binary | RAM / runtime | Notes |
|-----------|----------------|---------------|--------|
| **tailscale** | `GO_PKG_LDFLAGS -s -w` | `GOGC=10`, `GOMEMLIMIT=128MiB` | Overlay init; enable on first boot |
| **adguardhome** | `GO_PKG_LDFLAGS -s -w` | `gc=20`, `maxprocs=2`, 192 MiB soft limit | **Primary DNS — auto-start** |
| **cloudflared** | `GO_PKG_LDFLAGS -s -w` | `GOGC=10`, `GOMEMLIMIT=96MiB` | disabled until configured; log → `/tmp` |
| **NSS / ECM** | FW 12.5 + crypto | `pbuf=auto`; SW/HW flow offload **off** | ECM owns acceleration |
| **sqm / sqm-nss** | `nss-zk.qos` | interval **50ms**, min limit **400+** | `fq_codel` only; set rates then enable |
| **qos-scripts** | not installed | forced off if present | Conflicts with NSS SQM |
| **zram-swap** | — | 256 MiB, `lzo-rle` | Avoid half-RAM default |
| **haveged** | — | enabled early | Stock thresholds OK |
| **mdns-repeater** | — | `br-lan` only | No phantom `eth0.2` |
| **udp-broadcast-relay** | — | no auto rules | On-demand UCI only |
| **drill / ipset / ddns** | normal strip | CLI | No always-on cost |
| **luci-theme-argon** | theme assets | LuCI only | Re-cloned on sync |
| **shadow-all** | larger rootfs | login utils | Kept by request |

## Overlay map

```text
custom/files/
  etc/init.d/{tailscale,cloudflared}
  etc/config/{adguardhome,cloudflared,mdns_repeater,sqm}
  etc/sysctl.d/50-adguardhome.conf
  usr/lib/sqm/nss-zk.qos[.help]
  etc/uci-defaults/
    16_ensure_lan_dhcpv4
    97-sqm-nss-optimize
    98-component-optimize
    99-qol_nss_tailscale
    99-qol_wireless
```

## SQM enable

```bash
uci set sqm.wan.download='450000'   # kbit/s ~90–95% of real rate
uci set sqm.wan.upload='45000'
uci set sqm.wan.enabled='1'
uci commit sqm
/etc/init.d/sqm restart
```

## Rebuild

```bash
./custom/scripts/prepare.sh --feeds
./custom/scripts/build.sh
```
