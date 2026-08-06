# luci-app-dns-rewrites

OpenWrt package with LuCI UI and `dns-rewrite-apply` helper.

## Seed

```
CONFIG_PACKAGE_luci-app-dns-rewrites=y
CONFIG_PACKAGE_luci-i18n-dns-rewrites-zh-tw=y
```

`luci.mk` builds `luci-i18n-dns-rewrites-zh-tw` from `po/zh_Hant/dns-rewrites.po`.

## Layout

Standard LuCI application layout (`htdocs/`, `root/`, `po/`).
