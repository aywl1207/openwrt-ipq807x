# luci-app-wol-api

LuCI UI + CGI for token-protected Wake-on-LAN HTTP API (Home Assistant).

- Config: `/etc/config/wol_api`
- CGI: `/cgi-bin/wol` on uhttpd (port 8080)
- Menu: **Services → WOL API**

```
GET /cgi-bin/wol?action=list&token=TOKEN
GET /cgi-bin/wol?target=NAME&token=TOKEN
```
