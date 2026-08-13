# Site notes (QNAP 301W / custom fork)

## Production DNS (live stack)

```text
LAN clients → dnsmasq:53 → https-dns-proxy:5053 → Cloudflare Gateway DoH
Blocklists: Cloudflare Zero Trust (CGPS off-router) — not AdGuard Home
```

- First-boot: `96-dns-gateway-mode` enables `https-dns-proxy` + dnsmasq port 53 / `server=127.0.0.1#5053`
- Overlay ships public Cloudflare DoH so LAN DNS works immediately; **device-only (never git):** Gateway `resolver_url`, DNS rewrites, Wi‑Fi keys, tunnel token, healthcheck URLs
- Per-interface DHCP DNS for **iot/guest** is site-managed (not forced by overlay)
- Do **not** re-add AGH without revisiting RAM budget

### RAM policy (1GB IPQ807x)

| Do | Don't |
|----|--------|
| DNS via Gateway + thin `https-dns-proxy` | Re-install AGH with huge on-router lists |
| sysctl `65-ram-opt.conf` (swappiness 80, min_free 32M) + `99-net-perf.conf` | `drop_caches` cron |
| `mem-watch` + pstore after rebuild | Ignore SUnreclaim (~NSS tax) as “leak” |

### OOM / panic logs (after rebuild with kmod-pstore + kmod-ramoops)

```bash
ls -la /root/crashlogs/
cat /root/crashlogs/LAST
cat $(cat /root/crashlogs/LAST)/COMBINED.txt | less
tail -100 /root/crashlogs/mem-watch.log
```

Do **not** run `echo 3 > /proc/sys/vm/drop_caches` on a 1 GB router as routine maintenance.

---

## SQM (NSS)

### Generic rules

- Script: **`nss-zk.qos`**, qdisc: **`fq_codel`**
- Rates: ~**95%** of real up/down (kbit/s)
- Disable OpenWrt **software/hardware flow offloading** when using SQM + ECM
- Do not use `piece_of_cake.qos` / classic `qos-scripts` alongside NSS SQM

### Example (2.5Gbit class — interface name is site-specific)

```bash
# Replace IFACE with the real WAN device (e.g. 10g-2 on QNAP 301W)
IFACE='wan'          # or physical like 10g-2
DOWN=2375000         # kbit/s example: 0.95 * 2500000
UP=2375000

uci set sqm.wan_sqm=queue
uci set sqm.wan_sqm.enabled='1'
uci set sqm.wan_sqm.interface="$IFACE"
uci set sqm.wan_sqm.download="$DOWN"
uci set sqm.wan_sqm.upload="$UP"
uci set sqm.wan_sqm.qdisc='fq_codel'
uci set sqm.wan_sqm.script='nss-zk.qos'
uci set sqm.wan_sqm.qdisc_advanced='1'
uci set sqm.wan_sqm.iqdisc_opts='interval 50ms'
uci set sqm.wan_sqm.eqdisc_opts='interval 50ms'
uci commit sqm
/etc/init.d/sqm enable
/etc/init.d/sqm restart
```

If the WAN device comes up late, use the shipped hotplug helper  
`/etc/hotplug.d/iface/99-sqm-enabled` (restarts SQM only when the ifup device matches an **enabled** queue). Avoid long `sleep` loops and Wi‑Fi readiness waits for WAN shaping.

---

## Tailscale

- Daemon: package + optional overlay init (`GOGC=10`, `GOMEMLIMIT=128MiB`)
- UI: `luci-app-tailscale-community` + `luci-i18n-tailscale-community-zh-tw`
- Enable: `/etc/init.d/tailscale enable`
- Join: `tailscale up` or LuCI (do not put auth keys in git)
- Exit node / subnet routes: configure in LuCI or CLI; firewall zone may be auto-created by the app

---

## mdns-repeater

```bash
uci set mdns_repeater.main.enabled='1'
# Only real bridges — missing ifaces can crash the daemon
uci -q delete mdns_repeater.main.interface
uci add_list mdns_repeater.main.interface='br-lan'
# uci add_list mdns_repeater.main.interface='br-lan-jumbo'  # if present
uci commit mdns_repeater
/etc/init.d/mdns-repeater enable
/etc/init.d/mdns-repeater restart
```

No need to restart from `rc.local` if the init script is enabled.

---

## IPv6 (policy examples)

| Interface | Typical policy |
|-----------|----------------|
| `wan6` | `norelease='1'` (keep PD across renew) |
| `lan` / jumbo | SLAAC + `ra_flags` other-config (DNS via RA/RDNSS as designed) |
| `guest` | IPv4-only if isolation preferred |
| `iot` | ULA-only (`ip6class local`) if no public IPv6 needed |

Apply with `ifup wan6` / `odhcpd` restart rather than full `network reload` when possible (avoids long SSH drops).

---

## What stays off GitHub

- Root / AGH / Wi‑Fi passwords  
- Cloudflare tunnel token / cert  
- Status / healthcheck push URLs with tokens  
- Full `adguardhome.yaml` if it embeds credentials  
- Device-specific WAN MAC, static public IP, or internal topology you consider private  

Use local backups (e.g. host-side `backups/qnap-301w/`) for full config dumps.

---

## Checklist after sysupgrade (keep-settings)

1. `ping_group_range` → `sysctl net.ipv4.ping_group_range` shows `0	65535`  
2. `https-dns-proxy` running; `resolver_url` is Cloudflare public or your Gateway URL (not empty)  
3. SQM enabled on correct iface; `tc -s qdisc` / NSS path healthy (`nss-zk.qos`)  
4. Tailscale + LuCI app present if built into image  
5. `rc.local` still minimal (or only your documented extras)  
6. Cron: `mem-watch.sh` + any health checks (secrets only on device)  
7. `skb_recycler.opt.enable=1`, `network.globals.packet_steering=0`, CPU governor `performance`  
