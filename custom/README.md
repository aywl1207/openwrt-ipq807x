# Fork customizations (`custom/`)

**Single home for everything this fork owns.** Survives upstream sync via `PRESERVE.list`.

See **[docs/LAYOUT.md](docs/LAYOUT.md)** for the full maintenance map.

## Quick commands

```bash
./custom/scripts/prepare.sh --feeds     # overlay + feeds + Go -s -w + feed patches
./custom/scripts/prepare.sh --config    # + defconfig + verify
./custom/scripts/build.sh               # full image build
DEVICE=qnap_301w ./custom/scripts/build.sh
```

## Layout (summary)

| Path | Role |
|------|------|
| `files/` | Rootfs overlay (init, uci-defaults, sqm, configs) |
| `feed/` | Local OpenWrt feed (`src-link custom_feed`) |
| `patches/` | Official-feed patches applied by `prepare.sh --feeds` |
| `feeds.conf.append` | Registers local feed in `feeds.conf.default` |
| `config/clean_seed.config` | Package selection (`CONFIG_PACKAGE_*=y` only) |
| `config/seed_ipq807x_1g.config` | 1GB / NSS platform knobs |
| `config/required_symbols.txt` | Must-have `CONFIG_*=y` checks |
| `scripts/*.sh` | prepare / build / verify / sync helpers |
| `docs/` | BUILD, COMPONENTS, LAYOUT, SITE (no secrets) |
| `UPSTREAM_SHA` | Last synced `main_nss` tip |

## Workflows

| Workflow | File | Calls |
|----------|------|--------|
| Build images | `.github/workflows/build-ipq807x.yml` | `prepare.sh --feeds`, verify |
| Sync upstream | `.github/workflows/sync-upstream.yml` | `sync-backup.sh` / `sync-restore.sh` |

## First-boot / overlay notes

- `16_ensure_lan_dhcpv4` — only re-enables LAN DHCPv4 when LAN is static
- `96-dns-gateway-mode` — dnsmasq + https-dns-proxy (public Cloudflare DoH; Gateway URL is device-only)
- `97-sqm-nss-optimize` — pin `nss-zk.qos`; do not enable stock S50sqm
- `98-avahi-mdns-reflector` — Avahi on; disable leftover `mdns-repeater` if present
- `98-ipv6-optimize` — RA follows PD; `peerdns=0` if unset
- `98-component-optimize` — zram + pstore-save + mem-watch
- `99-nss-perf-pins` — flow offload off, packet_steering off, skb recycler, performance governor
- `99-qol_nss_tailscale` — Tailscale enable on first boot only
- `99-qol_wireless` — fill empty wireless fields only
- `etc/init.d/sqm-nss-defer` — SQM at S99 after NSS is up
- `etc/rc.local` — **minimal** (`exit 0`); see [docs/SITE.md](docs/SITE.md)
- `etc/sysctl.d/60-cloudflared-ping.conf` — `ping_group_range` for cloudflared
- `etc/sysctl.d/zz-net-perf.conf` — conntrack 64k (after `qca-nss-ecm.conf`) + no ICMP redirects
- `etc/hotplug.d/iface/99-sqm-enabled` — start enabled SQM queues on ifup
