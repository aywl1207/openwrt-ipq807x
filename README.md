![OpenWrt logo](include/logo.png)

[![Build Custom IPQ807x NSS WiFi for devices](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/custom_ipq807x.yml/badge.svg?branch=custom_main_nss)](https://github.com/aywl1207/openwrt-ipq807x/actions/workflows/custom_ipq807x.yml)

# openwrt-ipq807x (`custom_main_nss`)

Fork of [AgustinLorenzo/openwrt](https://github.com/AgustinLorenzo/openwrt) **NSS Wi‑Fi** tree, tuned for **Qualcomm IPQ807x routers with ~1 GB RAM**.

Not locked to a single board: multi-profile images follow upstream device list; memory profile is forced to **1024 MB**. Optional single-device builds via `DEVICE=...`.

## Included tools & packages

| Category | Components |
|----------|------------|
| **VPN / mesh** | [Tailscale](https://tailscale.com/) (`tailscale`) — `-s -w` + `GOGC=10` / `GOMEMLIMIT=128MiB` |
| **DNS / filter** | [AdGuard Home](https://adguard.com/adguard-home/overview.html) — `-s -w` + `gc=20` / `maxprocs=2` / 192 MiB soft limit |
| **Tunnel** | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) — `-s -w` + `GOGC=10` / `GOMEMLIMIT=96MiB` (disabled until configured) |
| **NSS offload** | `kmod-qca-nss-drv`, `kmod-qca-nss-ecm`, `kmod-qca-nss-crypto`, `nss-eip-firmware`, bridge/vlan/pppoe/qdisc managers; NSS FW **12.5** |
| **SQM / QoS** | `sqm-scripts`, `sqm-scripts-nss`, `luci-app-sqm`, `kmod-sched-cake` (installed, **not** auto-enabled) |
| **UI** | LuCI + **Argon** theme (`luci-theme-argon`), Traditional Chinese (`zh_Hant` / `*-zh-tw` i18n packs) |
| **Network utils** | `ddns-scripts-cloudflare`, `mdns-repeater` (br-lan only), `udp-broadcast-relay-redux`, `drill`, `ipset` |
| **Memory** | `zram-swap` + `kmod-zram` — **256 MiB** + `lzo-rle` (not half-RAM default) |
| **Entropy / misc** | `haveged` (enabled), `shadow-all`, `iwinfo` |

Per-component detail: [`docs/COMPONENT_OPTIMIZATIONS.md`](docs/COMPONENT_OPTIMIZATIONS.md).

First-boot QoL (via `custom/files` → rootfs): disable OpenWrt SW/HW **flow offloading** (ECM/NSS owns acceleration), `pbuf` memory profile `auto`, enable Tailscale service, wireless country defaults. LAN **DHCPv4** is kept as `server` when LAN is static (`16_ensure_lan_dhcpv4`; no other DHCP rewrites).

## Quick build (1 GB IPQ807x)

```bash
# Multi-device (uses .full_config device set) + 1GB seed + clean_seed packages
./scripts/build-ipq807x-1g.sh

# Optional: one board only
DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh
DEVICE=qnap_301w ./scripts/build-ipq807x-1g.sh
```

Config stack:

```text
.full_config  →  clean_seed.config  →  seed_ipq807x_1g.config  →  make defconfig
```

| File | Role |
|------|------|
| `clean_seed.config` | Enable/disable packages (Tailscale, AdGuard, Argon, NSS crypto, …) |
| `seed_ipq807x_1g.config` | `IPQ_MEM_PROFILE_1024`, NSS HIGH, ath11k NSS, shared kmods |
| `custom/files/` | Durable rootfs overlay (`/files` is gitignored) |
| `scripts/apply-component-optimize.sh` | Strip Go packages + materialize all RAM/runtime overlays |
| `custom/PRESERVE.list` | Paths restored after upstream sync |

More detail: [`docs/BUILD_TAILSCALE_NSS.md`](docs/BUILD_TAILSCALE_NSS.md), [`custom/README.md`](custom/README.md).

## Upstream sync

Manual only (Actions → **Sync Fork**). Runs a hard reset **only when** `upstream/main_nss` differs from `custom/UPSTREAM_SHA`. Use `force=true` to re-sync anyway. No weekly cron.

---

## Upstream OpenWrt project

OpenWrt Project is a Linux operating system targeting embedded devices. Instead
of trying to create a single, static firmware, OpenWrt provides a fully
writable filesystem with package management. This frees you from the
application selection and configuration provided by the vendor and allows you
to customize the device through the use of packages to suit any application.
For developers, OpenWrt is the framework to build an application without having
to build a complete firmware around it; for users this means the ability for
full customization, to use the device in ways never envisioned.

Sunshine!

## Download

Built firmware images are available for many architectures and come with a
package selection to be used as WiFi home router. To quickly find a factory
image usable to migrate from a vendor stock firmware to OpenWrt, try the
*Firmware Selector*.

* [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/)

If your device is supported, please follow the **Info** link to see install
instructions or consult the support resources listed below.

## 

An advanced user may require additional or specific package. (Toolchain, SDK, ...) For everything else than simple firmware download, try the wiki download page:

* [OpenWrt Wiki Download](https://openwrt.org/downloads)

## Development

To build your own firmware you need a GNU/Linux, BSD or macOS system (case
sensitive filesystem required). Cygwin is unsupported because of the lack of a
case sensitive file system.

### Requirements

You need the following tools to compile OpenWrt, the package names vary between
distributions. A complete list with distribution specific packages is found in
the [Build System Setup](https://openwrt.org/docs/guide-developer/build-system/install-buildsystem)
documentation.

```
binutils bzip2 diff find flex gawk gcc-6+ getopt grep install libc-dev libz-dev
make4.1+ perl python3.7+ rsync subversion unzip which
```

### Quickstart

1. Run `./scripts/feeds update -a` to obtain all the latest package definitions
   defined in feeds.conf / feeds.conf.default

2. Run `./scripts/feeds install -a` to install symlinks for all obtained
   packages into package/feeds/

3. Run `make menuconfig` to select your preferred configuration for the
   toolchain, target system & firmware packages.

4. Run `make` to build your firmware. This will download all sources, build the
   cross-compile toolchain and then cross-compile the GNU/Linux kernel & all chosen
   applications for your target system.

### Related Repositories

The main repository uses multiple sub-repositories to manage packages of
different categories. All packages are installed via the OpenWrt package
manager called `opkg`. If you're looking to develop the web interface or port
packages to OpenWrt, please find the fitting repository below.

* [LuCI Web Interface](https://github.com/openwrt/luci): Modern and modular
  interface to control the device via a web browser.

* [OpenWrt Packages](https://github.com/openwrt/packages): Community repository
  of ported packages.

* [OpenWrt Routing](https://github.com/openwrt/routing): Packages specifically
  focused on (mesh) routing.

* [OpenWrt Video](https://github.com/openwrt/video): Packages specifically
  focused on display servers and clients (Xorg and Wayland).

## Support Information

For a list of supported devices see the [OpenWrt Hardware Database](https://openwrt.org/supported_devices)

### Documentation

* [Quick Start Guide](https://openwrt.org/docs/guide-quick-start/start)
* [User Guide](https://openwrt.org/docs/guide-user/start)
* [Developer Documentation](https://openwrt.org/docs/guide-developer/start)
* [Technical Reference](https://openwrt.org/docs/techref/start)

### Support Community

* [Forum](https://forum.openwrt.org): For usage, projects, discussions and hardware advise.
* [Support Chat](https://webchat.oftc.net/#openwrt): Channel `#openwrt` on **oftc.net**.

### Developer Community

* [Bug Reports](https://bugs.openwrt.org): Report bugs in OpenWrt
* [Dev Mailing List](https://lists.openwrt.org/mailman/listinfo/openwrt-devel): Send patches
* [Dev Chat](https://webchat.oftc.net/#openwrt-devel): Channel `#openwrt-devel` on **oftc.net**.

## License

OpenWrt is licensed under GPL-2.0
