# DNS Rewrites

## Package + seed

| Item | Value |
|------|--------|
| Package | `custom/package/luci-app-dns-rewrites` |
| Seed | `CONFIG_PACKAGE_luci-app-dns-rewrites=y` |
| i18n (zh-tw) | `CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y` |
| Built from | `po/zh_Hant/dns-rewrites.po` via `luci.mk` → `dns-rewrites.zh-tw.lmo` |

Uses standard LuCI application layout (`htdocs/`, `root/`, `po/`) and `feeds/luci/luci.mk`.

## Standalone project

Copy `custom/package/luci-app-dns-rewrites` to its own repo/feed when needed.

## UI language

Set LuCI language to **正體中文** (zh-tw). Menu title and form strings load from the i18n package.
