# Fork customizations (`custom/`)

**Single home for everything this fork owns.** Survives upstream sync via `PRESERVE.list`.

See **[docs/LAYOUT.md](docs/LAYOUT.md)** for the full maintenance map.

## Quick commands

```bash
./custom/scripts/prepare.sh --feeds     # overlay + feeds + Go -s -w
./custom/scripts/prepare.sh --config    # + defconfig + verify
./custom/scripts/build.sh               # full image build
DEVICE=qnap_301w ./custom/scripts/build.sh
```

## Layout (summary)

| Path | Role |
|------|------|
| `files/` | Rootfs overlay (init, uci-defaults, sqm, configs) |
| `config/clean_seed.config` | Package selection |
| `config/seed_ipq807x_1g.config` | 1GB / NSS platform knobs |
| `config/required_symbols.txt` | Must-have `CONFIG_*=y` checks |
| `scripts/*.sh` | prepare / build / verify / sync helpers |
| `docs/` | BUILD, COMPONENTS, LAYOUT, **SITE** (runtime / rc.local policy) |
| `UPSTREAM_SHA` | Last synced `main_nss` tip |
| `feeds.conf.append` | Appended to `feeds.conf.default` (idempotent) |

## Workflows

| Workflow | File | Calls |
|----------|------|--------|
| Build images | `.github/workflows/build-ipq807x.yml` | `prepare.sh --feeds`, verify |
| Sync upstream | `.github/workflows/sync-upstream.yml` | `sync-backup.sh` / `sync-restore.sh` |

## First-boot network notes

- `16_ensure_lan_dhcpv4` — only re-enables LAN DHCPv4 when LAN is static
- `97-sqm-nss-optimize` — pin `nss-zk.qos`; classic qos off
- `98-component-optimize` — zram + **AdGuard Home enable/start** (primary DNS)
- `99-qol_nss_tailscale` — ECM/NSS offload prefs + Tailscale enable
- `etc/rc.local` — **minimal** (`exit 0`); see [docs/SITE.md](docs/SITE.md)
- `etc/sysctl.d/60-cloudflared-ping.conf` — `ping_group_range` for cloudflared
- `etc/hotplug.d/iface/99-sqm-enabled` — SQM restart when WAN iface is up
