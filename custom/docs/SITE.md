# Site notes (runtime / boot — no secrets)

## Production DNS

```text
LAN clients → dnsmasq:53 → https-dns-proxy:5053 → DoH
```

- First-boot: `96-dns-gateway-mode` enables `https-dns-proxy` + dnsmasq `server=127.0.0.1#5053`
- Overlay ships **public** Cloudflare DoH so first-boot DNS works
- **Device-only (never git):** tenant Gateway `resolver_url`, DNS rewrites, Wi‑Fi keys, tunnel token, healthcheck URLs
- Per-interface DHCP DNS for **iot/guest** is site-managed
- Do **not** re-add AdGuard Home without revisiting the 1GB RAM budget

### RAM policy (1GB IPQ807x)

| Do | Don't |
|----|--------|
| Thin `https-dns-proxy` + off-router lists | Huge on-router blocklists |
| `65-ram-opt.conf` + `zz-net-perf.conf` | `drop_caches` cron |
| `mem-watch` + pstore | Treat NSS SUnreclaim as a leak |

```bash
ls -la /root/crashlogs/
cat /root/crashlogs/LAST
tail -100 /root/crashlogs/mem-watch.log
```

---

## SQM (NSS)

- Script: **`nss-zk.qos`**, qdisc: **`fq_codel`**, interval **50ms**
- Rates: ~**95%** of real up/down (kbit/s)
- Software/hardware **flow offload off** (ECM/NSS own forwarding)
- Do not use cake / classic `qos-scripts` with NSS SQM
- **Do not enable stock S50sqm** (LuCI Save can turn it back on). Boot path is `sqm-nss-defer` (S99) + `99-sqm-enabled` hotplug
- New images leave queues **disabled** until you enable them
- Do not tick LuCI “Dangerous Configuration”

```bash
# Replace IFACE with the WAN device (board-specific)
uci set sqm.wan_sqm=queue
uci set sqm.wan_sqm.enabled='1'
uci set sqm.wan_sqm.interface="$IFACE"
uci set sqm.wan_sqm.download='2375000'
uci set sqm.wan_sqm.upload='2375000'
uci set sqm.wan_sqm.qdisc='fq_codel'
uci set sqm.wan_sqm.script='nss-zk.qos'
uci commit sqm
/etc/init.d/sqm-nss-defer restart
```

---

## mDNS (Avahi)

`mdns-repeater` is **not** in the image. Use **avahi-nodbus-daemon** as a reflector:

- Overlay: `etc/avahi/avahi-daemon.conf` — `enable-reflector=yes`, `allow-interfaces=br-lan,br-lan2`
- `98-avahi-mdns-reflector` disables a leftover `mdns-repeater` on keep-settings devices
- Do not run Avahi and mdns-repeater together
- Do not add IoT/guest/WAN to the reflector

Site-only UDP relays (doorbell, DIAL, …) stay in UCI on the device, not in git.

---

## Tailscale

- Package + overlay init (`GOGC=10`, `GOMEMLIMIT=128MiB`)
- UI: `luci-app-tailscale-community` (zh-TW)
- Join with `tailscale up` or LuCI — **no auth keys in git**

---

## IPv6 (policy)

| Interface | Typical policy |
|-----------|----------------|
| `wan6` | `norelease=1`, `peerdns=0` |
| `lan` / second LAN | SLAAC + `ra_flags` other-config; RA lifetime follows PD |
| `guest` | IPv4-only if isolation preferred |
| `iot` | ULA-only (`ip6class local`) if no public IPv6 |

`98-ipv6-optimize` applies the safe defaults without overwriting a peerdns you already set.

---

## What stays off GitHub

- Root / Wi‑Fi passwords  
- Cloudflare tunnel token / cert / tenant Gateway URL  
- Healthcheck URLs with tokens  
- Device WAN MAC, public IP, DHCP host maps, SSID lists  

Use a host-side backup (not this repo) for full config dumps.

---

## Checklist after sysupgrade (keep-settings)

1. `sysctl net.ipv4.ping_group_range` → `0	65535`  
2. `https-dns-proxy` running; `resolver_url` not empty  
3. SQM: only S99 `sqm-nss-defer`; `tc qdisc` shows `nsstbl` / `nssfq_codel` if you enabled a queue  
4. Avahi running; `mdns-repeater` not running  
5. `skb_recycler.opt.enable=1`, `packet_steering=0`, governor `performance`  
6. `nf_conntrack_max` is **65536** (not 32768 from `qca-nss-ecm.conf`)  
