# DNS Rewrites

## Do we need a separate git project?

| Option | When |
|--------|------|
| **Package in monorepo** `custom/package/luci-app-dns-rewrites` + **seed** | Default (this fork) |
| **Own git repo / feed** | Reuse across many OpenWrt trees without copying |

OpenWrt-native pattern: **package + `CONFIG_PACKAGE_…=y` in seed**, not only `files/` overlay.

## Build integration

1. Source: `custom/package/luci-app-dns-rewrites/`
2. `prepare.sh` → `materialize_packages` → `package/custom/luci-app-dns-rewrites/`
3. Seed (`clean_seed.config`): `CONFIG_PACKAGE_luci-app-dns-rewrites=y`
4. `required_symbols.txt` lists the same symbol for CI verify

## Extract to standalone project

```bash
cp -a custom/package/luci-app-dns-rewrites /path/to/luci-app-dns-rewrites
# feeds.conf:
#   src-link dnsrw /path/to   # directory that contains luci-app-dns-rewrites/
```

## Runtime

| Path | Role |
|------|------|
| LuCI Network → DNS Rewrites | UI |
| `/etc/config/dns_rewrite` | UCI (site hosts = on-device) |
| `/usr/sbin/dns-rewrite-apply` | Generate conf + restart dnsmasq |
| `/etc/dnsmasq.d/10-dns-rewrites.conf` | Generated |

| Type | dnsmasq |
|------|---------|
| Private IP | `address=` + `local=` |
| Public | `server=/name/127.0.0.1#5053` |
