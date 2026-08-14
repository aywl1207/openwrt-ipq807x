![OpenWrt logo](include/logo.png)

[![Build IPQ807x NSS](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/build-ipq807x.yml/badge.svg?branch=custom_main_nss)](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/build-ipq807x.yml)

OpenWrt is a Linux operating system targeting embedded devices. Instead of a
single static firmware, it provides a fully writable filesystem with package
management. That frees you from the vendor’s application selection and lets you
customize the device with packages.

Sunshine!

# openwrt-ipq807x (`custom_main_nss`)

Fork of [AgustinLorenzo/openwrt](https://github.com/AgustinLorenzo/openwrt)
**NSS Wi‑Fi**, tuned for **Qualcomm IPQ807x boards with ~1 GB RAM**.

All fork-owned files live under [`custom/`](custom/). See
[`custom/docs/LAYOUT.md`](custom/docs/LAYOUT.md).

| | |
|---|---|
| **VPN** | Tailscale (`-s -w`, `GOGC=10`, LuCI zh-TW) |
| **DNS** | dnsmasq + `https-dns-proxy` (public Cloudflare DoH in the image; Gateway URL stays on-device) |
| **Tunnel** | cloudflared (disabled until configured) |
| **NSS** | nss-drv / ecm / crypto / eip-firmware (FW **12.5**) |
| **SQM** | `nss-zk.qos` + `fq_codel` (no cake / sw offload) |
| **UI** | LuCI + Argon + Traditional Chinese |
| **Net** | Avahi reflector, udp-broadcast-relay-redux, Cloudflare DDNS, drill, ipset |
| **RAM** | zram 256 MiB lzo-rle, haveged |

More: [`COMPONENTS.md`](custom/docs/COMPONENTS.md) · [`SITE.md`](custom/docs/SITE.md) (no secrets) · [`BUILD.md`](custom/docs/BUILD.md)

## Build

```bash
./custom/scripts/build.sh
DEVICE=qnap_301w ./custom/scripts/build.sh
```

```text
.full_config → custom/config/clean_seed.config → custom/config/seed_ipq807x_1g.config → make defconfig
```

| Path | Role |
|------|------|
| `custom/config/` | Package seed + 1GB / NSS knobs |
| `custom/files/` | Rootfs overlay (materialized to gitignored `files/`) |
| `custom/feed/` | Local packages (`src-link`) |
| `custom/patches/` | Patches applied onto official feeds |
| `custom/scripts/` | prepare / build / verify / sync |
| `custom/PRESERVE.list` | Restored after upstream sync |

Upstream: Actions → **Sync upstream** when `upstream/main_nss` ≠ `custom/UPSTREAM_SHA`.

## Development

You need a GNU/Linux, BSD or macOS system (case-sensitive filesystem). Cygwin
is unsupported.

### Requirements

Package names vary by distribution. See
[Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem).

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.8+ rsync subversion unzip which
```

This fork’s entry point is `./custom/scripts/build.sh` (feeds, overlay, NSS
seed). The stock `./scripts/feeds` + `make menuconfig` + `make` path still
exists underneath.

### Related repositories

* [LuCI Web Interface](https://github.com/openwrt/luci)
* [OpenWrt Packages](https://github.com/openwrt/packages)
* [OpenWrt Routing](https://github.com/openwrt/routing)
* [OpenWrt Video](https://github.com/openwrt/video)

## Support

* [Documentation](https://openwrt.org/docs/start)
* [Hardware Database](https://openwrt.org/supported_devices)
* [Forum](https://forum.openwrt.org)
* [Bug Reports](https://bugs.openwrt.org)

NSS / this fork: use this repository’s issues. Stock OpenWrt images from the
[Firmware Selector](https://firmware-selector.openwrt.org/) do **not** include
these NSS customizations.

## License

OpenWrt is licensed under GPL-2.0
