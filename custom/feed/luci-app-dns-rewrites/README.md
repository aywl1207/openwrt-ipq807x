# luci-app-dns-rewrites

OpenWrt **feed package** (LuCI DNS Rewrites + apply helper).

## In this fork

- Feed path: `custom/feed/` (`src-link custom_feed custom/feed`)
- Enable in image seed: `CONFIG_PACKAGE_luci-app-dns-rewrites=y`
- zh-tw: `CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y` (from `po/zh_Hant/`)

## Standalone

Publish this directory under any feed root and `src-link` / `src-git` that feed.
