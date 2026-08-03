# Fork customizations (survive upstream sync)

Restored by `.github/workflows/sync_fork_with_customization.yaml` using `PRESERVE.list`.

## Layout

| Path | Purpose |
|------|---------|
| `custom/files/` | Rootfs overlay → copied to gitignored `files/` at build time |
| `custom/files/etc/init.d/tailscale` | RAM-tuned init (`GOGC=10`, `GOMEMLIMIT=128MiB`) |
| `custom/files/etc/uci-defaults/16_ensure_lan_dhcpv4` | Keep LAN DHCPv4 `server` when LAN is static |
| `custom/files/etc/config/sqm` + `usr/lib/sqm/nss-zk.qos` | NSS SQM template + fork-tuned shaper |
| `custom/files/etc/uci-defaults/97-sqm-nss-optimize` | Pin `nss-zk.qos`; disable classic qos-scripts |
| `custom/files/etc/uci-defaults/98-component-optimize` | zram; **enable+start AdGuard Home** (primary DNS); cloudflared |
| `custom/files/etc/uci-defaults/99-qol_nss_tailscale` | Disable SW/HW flow offload; enable Tailscale |
| `custom/files/etc/uci-defaults/99-qol_wireless` | Country/radios/SQM defaults (no DHCP) |
| `custom/feeds.conf.append` | Appended to upstream `feeds.conf.default` after sync/build |
| `custom/UPSTREAM_SHA` | Last synced `upstream/main_nss` tip (skip sync if unchanged) |
| `custom/PRESERVE.list` | Backup/restore list for the sync workflow |
| `clean_seed.config` | Package enables (Tailscale, AdGuard, Cloudflare, Argon, NSS…) |
| `seed_ipq807x_1g.config` | 1GB RAM profile + shared NSS knobs |
| `scripts/build-ipq807x-1g.sh` | One-shot build |
| `scripts/apply-component-optimize.sh` | All Go packages `-s -w` + materialize overlays |
| `scripts/apply-tailscale-optimize.sh` | Wrapper → `apply-component-optimize.sh` |

## Build

```bash
./scripts/build-ipq807x-1g.sh
DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh   # optional single board
```

## Sync

Manual **workflow_dispatch** only. Syncs when `upstream/main_nss` ≠ `custom/UPSTREAM_SHA`.
Force with `force=true`.

## First-boot network note

`16_ensure_lan_dhcpv4` only re-enables LAN DHCPv4 (`server`) when
`network.lan.proto=static` and `dhcp.lan.dhcpv4` was left `disabled` by
`15_odhcpd`. WAN and other interfaces are not modified.
