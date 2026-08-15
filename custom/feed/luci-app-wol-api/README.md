# luci-app-wol-api

LuCI UI + CGI for token-protected Wake-on-LAN HTTP API (Home Assistant).

- Config: `/etc/config/wol_api`
- CGI: `/cgi-bin/wol` on uhttpd (port 8080)
- Menu: **Services → WOL API**
- zh-tw: `CONFIG_PACKAGE_luci-i18n-wol-api-zh-tw=y` (from `po/zh_Hant/`)
- LuCI **Save & Apply** ubus-commits `wol_api` only (does not reload Wi-Fi).
- CGI rejects non-netdev `interface=` values (no shell passthrough).

## Auth (OpenWrt uhttpd)

| Method | Works? |
|--------|--------|
| `?token=TOKEN` in URL | Yes |
| `Authorization: Bearer TOKEN` | Yes (recommended for HA) |
| `X-WOL-Token: TOKEN` | **No** — uhttpd does not pass custom headers to CGI |

### Home Assistant

```yaml
rest_command:
  wol_example_pc:
    url: "http://192.168.1.1:8080/cgi-bin/wol?target=example-pc"
    method: GET
    headers:
      Authorization: "Bearer YOUR_TOKEN_HERE"
```

Or put token in the URL (also fine on LAN):

```yaml
rest_command:
  wol_example_pc:
    url: "http://192.168.1.1:8080/cgi-bin/wol?target=example-pc&token=YOUR_TOKEN_HERE"
    method: GET
```
