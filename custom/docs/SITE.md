# Runtime / site configuration guide

Generic settings for this fork on IPQ807x (~1 GB). **Do not commit secrets** (passwords, tunnel tokens, status-push URLs, Wi‑Fi keys).

| Layer | What belongs here |
|-------|-------------------|
| **Image (`custom/files/`)** | Defaults safe for every board: sysctl, empty `rc.local`, SQM/AGH UCI seeds, NSS QoS scripts |
| **This doc** | How to operate; example commands with placeholders |
| **On-device only** | Tokens, passwords, real WAN iface name, exact line rates, cron status URLs |

Related: [COMPONENTS.md](COMPONENTS.md) (package knobs), [BUILD.md](BUILD.md) (images).

---

## Boot policy (`rc.local`)

**Prefer UCI + procd.** Do not patch `/etc/init.d/*` from `rc.local`.

| Concern | Preferred place |
|---------|-----------------|
| cloudflared ICMP (QUIC/ICMP) | `sysctl.d` → `net.ipv4.ping_group_range` |
| AdGuard Home start + RAM | `/etc/config/adguardhome` + `/etc/init.d/adguardhome enable` |
| SQM | `/etc/config/sqm` + `/etc/init.d/sqm enable` (+ optional iface hotplug) |
| mdns-repeater | UCI `mdns_repeater` + init enable |
| Filter list refresh | **cron** (not every boot) |

Stock image ships a **minimal** `/etc/rc.local` (`exit 0` only). Site-specific deferred jobs, if any, should stay thin.

```sh
# /etc/rc.local — preferred end state
exit 0
```

---

## cloudflared

```text
# shipped as custom/files/etc/sysctl.d/60-cloudflared-ping.conf
net.ipv4.ping_group_range = 0 65535
```

- Keep tunnel **token** only on the router (`/etc/config/cloudflared`).
- Log to `/tmp` when possible (less flash wear).
- Do not enable in image defaults until a token exists.

---

## AdGuard Home (primary DNS)

### UCI (generic)

```bash
uci set adguardhome.config.gc='20'
uci set adguardhome.config.maxprocs='2'
uci set adguardhome.config.memlimit='201326592'   # 192 MiB, bytes
# Intentional tmpfs workdir (OpenWrt /var -> /tmp): less flash wear
uci set adguardhome.config.work_dir='/var/lib/adguardhome'
uci commit adguardhome
/etc/init.d/adguardhome enable
/etc/init.d/adguardhome-filters enable   # EVERY boot: re-download filter lists
/etc/init.d/adguardhome restart
```

- Use **package UCI** for `GOGC` / `GOMEMLIMIT` / `GOMAXPROCS`.  
  **Never** `sed` `/etc/init.d/adguardhome` on boot.
- **`work_dir=/var/lib/adguardhome`** sits on tmpfs by design (saves flash; querylog/stats do not thrash overlay).
- **Must** enable `adguardhome-filters` (START=99): waits for AGH + WAN, then runs `filter-refresh.sh` on **every** boot.
- Until boot refresh finishes, blocking may be incomplete for a short window.

### Filter refresh (boot every time + daily cron, secrets on device)

```bash
# Example — store auth outside the script if possible
# /etc/adguardhome/api.env  (mode 600, NOT in git)
#   AGH_URL=http://127.0.0.1:8081
#   AGH_AUTH_HEADER='Authorization: Basic <base64 user:pass>'

# boot: /etc/init.d/adguardhome-filters (START=99) — always refresh
# cron (root), e.g. daily:
# 15 4 * * * /etc/adguardhome/filter-refresh.sh
```

Do **not** run `echo 3 > /proc/sys/vm/drop_caches` on a 1 GB router as routine maintenance.

### IPv6 DNS

AGH should listen on IPv4 and IPv6 (`bind_hosts` include `0.0.0.0` and `::`) when LAN has GUA/ULA DNS options.

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
2. AGH running; UCI `gc`/`memlimit` as above; **no** sed lines in `/etc/init.d/adguardhome`  
3. SQM enabled on correct iface; `tc -s qdisc` / NSS path healthy  
4. Tailscale + LuCI app present if built into image  
5. `rc.local` still minimal (or only your documented extras)  
6. Cron: filter refresh + any health checks (secrets only on device)  
