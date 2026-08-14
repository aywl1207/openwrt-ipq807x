# Component matrix (custom fork)

| Component | Package / file | Runtime | Notes |
|-----------|----------------|---------|--------|
| **DNS** | `https-dns-proxy` + stock `dnsmasq` | always | Public Cloudflare DoH in git; Gateway URL on device |
| **DNS first-boot** | `96-dns-gateway-mode` | first boot | dnsmasq `:53` → `127.0.0.1#5053` |
| **DNS rewrites UI** | `custom/feed/luci-app-dns-rewrites` | seed | Local feed; enable in `clean_seed.config` |
| **WOL API** | `custom/feed/luci-app-wol-api` | seed | Token API for automations; no site hosts in git |
| **UDP broadcast relay** | `custom/feed/udp-broadcast-relay-redux` | seed | Binary + init; site port/iface UCI is device-only |
| **mDNS** | `avahi-nodbus-daemon` | always | Reflector `br-lan`↔`br-lan2`; not `mdns-repeater` |
| **OOM / crash** | `kmod-pstore` + `pstore-save` | boot | Dumps → `/root/crashlogs/` |
| **mem-watch** | `/usr/sbin/mem-watch.sh` | cron `*/5` | RAM pressure log |
| **zram-swap** | — | 256 MiB, `lzo-rle` | Avoid half-RAM default |
| **Tailscale** | package + LuCI community | user | GOGC=10, GOMEMLIMIT |
| **cloudflared** | package | optional | Token on device only |
| **SQM** | `nss-zk.qos` + `sqm-nss-defer` | wan | NSS qdisc; S99, not S50 |

## Overlay layout (`custom/files`)

```text
etc/avahi/avahi-daemon.conf
etc/config/{cloudflared,https-dns-proxy,sqm}
etc/init.d/{avahi-daemon,sqm-nss-defer,cloudflared,tailscale,pstore-save}
etc/sysctl.d/60-cloudflared-ping.conf
etc/sysctl.d/65-ram-opt.conf
etc/sysctl.d/zz-net-perf.conf
etc/uci-defaults/16_ensure_lan_dhcpv4
etc/uci-defaults/96-dns-gateway-mode
etc/uci-defaults/96-https-dns-resolver-fallback
etc/uci-defaults/97-sqm-nss-optimize
etc/uci-defaults/98-*
etc/uci-defaults/99-nss-perf-pins
etc/uci-defaults/99-qol_nss_tailscale
etc/uci-defaults/99-qol_wireless
usr/lib/sqm/nss-zk.qos
usr/sbin/mem-watch.sh
```

**Not shipped:** AdGuard Home, `mdns-repeater` package, site DHCP/firewall/Wi‑Fi.
