# DNS Rewrites

## Feed (not overlay materialize)

| Piece | Location |
|-------|----------|
| **Feed package** | `custom/feed/luci-app-dns-rewrites/` |
| **Feed registration** | `custom/feeds.conf.append` → `src-link custom_feed custom/feed` |
| **Image selection** | seed: `CONFIG_PACKAGE_luci-app-dns-rewrites=y` |
| **i18n** | seed: `CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y` |

`prepare.sh` appends the feed and runs `./scripts/feeds update/install`
(including explicit `feeds install luci-app-dns-rewrites`).

**Seed** only *selects* packages; the **feed** supplies the source.
Do not put package trees under `custom/package` / `package/custom`.

## Extract as standalone feed repo

```bash
# repo root = parent of luci-app-dns-rewrites/
# feeds.conf:
src-link dnsrw /path/to/parent
```

## Types

| Type | dnsmasq |
|------|---------|
| Private IP | `address=` + `local=` |
| Public | `server=/name/127.0.0.1#5053` |

## UI language

Set LuCI language to **正體中文** (zh-tw). Menu/form strings come from
`CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw` (`po/zh_Hant/`).
