# Fork customizations (survive weekly upstream sync)

Everything under `custom/` plus the paths listed in `PRESERVE.list` is
restored after `git reset --hard upstream/main_nss` by
`.github/workflows/sync_fork_with_customization.yaml`.

## Layout

| Path | Purpose |
|------|---------|
| `custom/files/` | OpenWrt rootfs overlay (copied to gitignored `files/` at build time) |
| `custom/feeds.conf.append` | Appended to upstream `feeds.conf.default` after sync |
| `custom/patches/tailscale/` | Reference patches for Tailscale strip/GOGC |
| `custom/scripts/` | Mirror of build helpers (also live under `scripts/`) |
| `clean_seed.config` | Package seed overlay (Tailscale, AdGuard, NSS crypto, …) |
| `seed_qnap_301w.config` | QNAP QHora-301W single-device seed |
| `seed_tailscale_nss.config` | Optional Tailscale + NSS fragment |

## Local / CI build order

```bash
# 1) materialize rootfs overlay
rsync -a custom/files/ files/

# 2) feeds + Tailscale optimize
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/apply-tailscale-optimize.sh

# 3) config
cp -f .full_config .config
cat clean_seed.config >> .config
# QNAP 301W only:
cat seed_qnap_301w.config >> .config
make defconfig

# or one-shot:
./scripts/build-qnap-301w.sh
```

## Adding a new preserved file

1. Put durable content under `custom/` when possible.
2. Add the path to `custom/PRESERVE.list` (one path per line).
3. Ensure the sync workflow restores it (reads `PRESERVE.list`).
