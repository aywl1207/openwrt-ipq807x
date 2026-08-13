# Component matrix (custom fork)

| Component | Package / file | Runtime | Notes |
|-----------|----------------|---------|--------|
| **DNS** | `https-dns-proxy` + stock `dnsmasq` | always | DoH → **Cloudflare Gateway**; blocklists live in Zero Trust (CGPS), not on-router |
| **DNS first-boot** | `96-dns-gateway-mode` | first boot | dnsmasq port 53, `server=127.0.0.1#5053` only — **no site rewrites in git** |
| **DNS rewrites UI** | `custom/feed/luci-app-dns-rewrites` | image (seed) | LuCI app via local feed; enable `CONFIG_PACKAGE_luci-app-dns-rewrites` |
| **OOM / crash forensics** | `kmod-pstore` + `kmod-ramoops` + `pstore-save` | boot | Mount `/sys/fs/pstore`; copy dumps → `/root/crashlogs/pstore-*` |
| **mem-watch** | `/usr/sbin/mem-watch.sh` | cron `*/5` | Soft RAM pressure log → `/root/crashlogs/mem-watch.log` |
| **zram-swap** | — | 256 MiB, `lzo-rle` | Avoid half-RAM default |
| **Tailscale** | `tailscale` + LuCI community | user | GOGC=10, GOMEMLIMIT |
| **cloudflared** | package | optional | tunnel token on device only |
| **SQM** | `sqm-scripts-nss` + `nss-zk.qos` | wan | NSS qdisc path |

## Overlay layout (custom/files)

```text
etc/config/https-dns-proxy          # Gateway DoH endpoint
etc/config/{cloudflared,mdns_repeater,sqm}
etc/sysctl.d/60-cloudflared-ping.conf
etc/sysctl.d/65-ram-opt.conf
etc/sysctl.d/99-net-perf.conf
etc/uci-defaults/96-dns-gateway-mode
etc/uci-defaults/98-component-optimize
etc/init.d/pstore-save
usr/sbin/mem-watch.sh
usr/lib/sqm/nss-zk.qos
```

**Not shipped:** AdGuard Home (package + overlay). Update CGPS lists off-router (PC/NAS/GitHub Actions).
