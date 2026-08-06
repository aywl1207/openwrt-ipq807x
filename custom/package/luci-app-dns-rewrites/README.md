# luci-app-dns-rewrites

OpenWrt package: LuCI **Network → DNS Rewrites** plus `/usr/sbin/dns-rewrite-apply`.

## Types

| Type | Effect |
|------|--------|
| Private IP | `address=/domain/ip` + `local=/domain/` |
| Public | `server=/domain/127.0.0.1#5053` (local DoH / Gateway) |

## Build (this monorepo)

- Package lives in `custom/package/luci-app-dns-rewrites`
- `prepare.sh` links it into `package/custom/`
- Seed: `CONFIG_PACKAGE_luci-app-dns-rewrites=y`

## Standalone feed (optional)

Copy this directory into any feed tree (or publish as its own git repo) and:

```
src-link dns_rewrites /path/to/parent   # parent contains luci-app-dns-rewrites/
```

Or as a single-package feed root:

```
src-link dns_rewrites /path/to/luci-app-dns-rewrites/..
```

## Site data

`/etc/config/dns_rewrite` ships empty of hostnames. Configure on device or restore backup after flash.
