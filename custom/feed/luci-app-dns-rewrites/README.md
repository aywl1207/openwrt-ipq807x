# luci-app-dns-rewrites

OpenWrt **feed package** (LuCI DNS Rewrites + apply helper).

## In this fork

- Feed path: `custom/feed/` (`src-link custom_feed custom/feed`)
- Enable in image seed: `CONFIG_PACKAGE_luci-app-dns-rewrites=y`
- zh-tw: `CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y` (from `po/zh_Hant/`)
- Version: see `PKG_VERSION` in `Makefile`

## Behaviour

| Type | Generated dnsmasq |
|------|-------------------|
| Private IP | `address=` + `local=` |
| Public | `server=/name/<upstream>` |

**Upstream** (public rules), first match wins:

1. env `DNS_REWRITE_DOH`
2. UCI `dns_rewrite.globals.upstream`
3. `https-dns-proxy` listen_addr#listen_port
4. `127.0.0.1#5053`

Apply **only** ensures `dhcp.@dnsmasq[0].confdir` when unset; it does **not** wipe
`server` / `address` / `cname` lists. dnsmasq restarts only when the generated
file (or confdir) actually changes.

## Standalone

Publish this directory under any feed root and `src-link` / `src-git` that feed.
