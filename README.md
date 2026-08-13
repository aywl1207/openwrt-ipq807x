![OpenWrt logo](include/logo.png)

[![Build IPQ807x NSS](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/build-ipq807x.yml/badge.svg?branch=custom_main_nss)](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/build-ipq807x.yml)

# openwrt-ipq807x (`custom_main_nss`)

Fork of [AgustinLorenzo/openwrt](https://github.com/AgustinLorenzo/openwrt) **NSS Wi‑Fi** tree, tuned for **Qualcomm IPQ807x routers with ~1 GB RAM**.

**All fork-owned files live under [`custom/`](custom/)** — see [`custom/docs/LAYOUT.md`](custom/docs/LAYOUT.md).

## Included tools & packages

| Category | Components |
|----------|------------|
| **VPN / mesh** | Tailscale — `-s -w` + `GOGC=10` / `GOMEMLIMIT=128MiB` + **LuCI** (`luci-app-tailscale-community`, zh-TW) |
| **DNS / filter** | `https-dns-proxy` + dnsmasq → Cloudflare Gateway / public DoH (no AGH) |
| **Tunnel** | cloudflared — optimized, disabled until configured |
| **NSS offload** | nss-drv / ecm / crypto / eip-firmware; FW **12.5** |
| **SQM / QoS** | **NSS** `nss-zk.qos` + `fq_codel`; classic qos-scripts off |
| **UI** | LuCI + **Argon** + Traditional Chinese |
| **Network utils** | Cloudflare DDNS, mdns-repeater, udp-broadcast-relay-redux, drill, ipset |
| **Memory** | zram 256 MiB + lzo-rle; haveged |

Details: [`custom/docs/COMPONENTS.md`](custom/docs/COMPONENTS.md).  
Runtime / boot / site config (no secrets): [`custom/docs/SITE.md`](custom/docs/SITE.md).

## Quick build

```bash
./custom/scripts/build.sh

# Optional single board
DEVICE=dynalink_dl-wrx36 ./custom/scripts/build.sh
DEVICE=qnap_301w ./custom/scripts/build.sh
```

Config stack:

```text
.full_config → custom/config/clean_seed.config → custom/config/seed_ipq807x_1g.config → make defconfig
```

| Path | Role |
|------|------|
| `custom/config/clean_seed.config` | Packages (Tailscale, DoH, Argon, NSS, …) |
| `custom/config/seed_ipq807x_1g.config` | `IPQ_MEM_PROFILE_1024`, NSS HIGH, ath11k NSS |
| `custom/files/` | Rootfs overlay (`files/` is gitignored) |
| `custom/scripts/` | prepare / build / verify / sync |
| `custom/PRESERVE.list` | Paths restored after upstream sync |

More: [`custom/docs/BUILD.md`](custom/docs/BUILD.md), [`custom/README.md`](custom/README.md).

## Upstream sync

Manual Actions → **Sync upstream**. Runs only when `upstream/main_nss` ≠ `custom/UPSTREAM_SHA` (or `force=true`).

## Upstream OpenWrt

OpenWrt is a Linux OS for embedded devices with a fully writable filesystem and package management.

Sunshine!

### Requirements

See [Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem).

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.7+ rsync subversion unzip which
```

### Support

* [Forum](https://forum.openwrt.org)
* [Bug Reports](https://bugs.openwrt.org)

## License

OpenWrt is licensed under GPL-2.0
