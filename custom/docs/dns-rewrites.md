# DNS Rewrites

## Feed (not overlay materialize)

| Piece | Location |
|-------|----------|
| **Feed package** | `custom/feed/luci-app-dns-rewrites/` |
| **Feed registration** | `custom/feeds.conf.append` → `src-link custom_feed custom/feed` |
| **Image selection** | seed: `CONFIG_PACKAGE_luci-app-dns-rewrites=y` |
| **i18n** | seed: `CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y` |
| **Version** | `PKG_VERSION` in package `Makefile` |

`prepare.sh` appends the feed and runs `./scripts/feeds update/install`
(including explicit `feeds install luci-app-dns-rewrites`).

**Seed** only *selects* packages; the **feed** supplies the source.
Do not put package trees under `custom/package` / `package/custom`.

## Behaviour

| Type | dnsmasq |
|------|---------|
| Private IP | `address=` + `local=` + `rebind-domain-ok=` (else LAN clients get a rebind drop) |
| Public | `server=/name/<upstream>` |

**Upstream** for public rules (first match):

1. env `DNS_REWRITE_DOH`
2. UCI `dns_rewrite.globals.upstream`
3. `https-dns-proxy` listen_addr#listen_port
4. `127.0.0.1#5053`

**Save & Apply** must ubus-commit `dns_rewrite` (LuCI session overlay) before
`dns-rewrite-apply`. A CLI `uci commit` does not see that overlay, so the
generated conf used to stay stale. The apply script still CLI-commits
`/tmp/.uci` for non-LuCI callers. `init.d/dns-rewrite` is a procd oneshot
with `procd_add_reload_trigger dns_rewrite` so a committed package also
regenerates the conf.

Apply is soft on `dhcp` UCI: only sets `confdir=/etc/dnsmasq.d` when **unset**.
It does **not** clear `server` / `address` / `cname`. dnsmasq restarts only when
the generated conf (or confdir) changes.

`/etc/config/dns_rewrite` is a **conffile** (survives opkg upgrade).

Legacy `/etc/config/aykc_dns` is copied once to `dns_rewrite` if missing.

## Extract as standalone feed repo

```bash
# repo root = parent of luci-app-dns-rewrites/
# feeds.conf:
src-link dnsrw /path/to/parent
```

## UI language

Set LuCI language to **正體中文** (zh-tw). Menu/form strings come from
`CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw` (`po/zh_Hant/`).
