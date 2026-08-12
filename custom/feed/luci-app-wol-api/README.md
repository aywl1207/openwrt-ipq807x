# luci-app-wol-api

LuCI UI + CGI for token-protected Wake-on-LAN HTTP API (Home Assistant).

- Config: `/etc/config/wol_api`
- CGI: `/cgi-bin/wol` on uhttpd (port 8080)
- Menu: **Services → WOL API**

## Auth (OpenWrt uhttpd)

| Method | Works? |
|--------|--------|
| `?token=TOKEN` in URL | Yes |
| `Authorization: Bearer TOKEN` | Yes (recommended for HA) |
| `X-WOL-Token: TOKEN` | **No** — uhttpd does not pass custom headers to CGI |

### Home Assistant

```yaml
rest_command:
  wol_aykc_pc:
    url: "http://192.168.20.1:8080/cgi-bin/wol?target=AYKC-PC"
    method: GET
    headers:
      Authorization: "Bearer YOUR_TOKEN_HERE"
```

Or put token in the URL (also fine on LAN):

```yaml
rest_command:
  wol_aykc_pc:
    url: "http://192.168.20.1:8080/cgi-bin/wol?target=AYKC-PC&token=YOUR_TOKEN_HERE"
    method: GET
```
