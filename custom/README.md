# Fork customizations (survive upstream sync)

Everything under `custom/` plus the paths listed in `PRESERVE.list` is
restored after `git reset --hard upstream/main_nss` by
`.github/workflows/sync_fork_with_customization.yaml`.

## When sync runs

- **No weekly cron** — only `workflow_dispatch` (Actions → Sync Fork → Run).
- Sync **runs only if** `upstream/main_nss` SHA ≠ `custom/UPSTREAM_SHA`
  (or that marker is missing). Use **force=true** to re-sync anyway.
- After a successful sync, the workflow writes the new upstream tip to
  `custom/UPSTREAM_SHA`.

## Layout

| Path | Purpose |
|------|---------|
| `custom/files/` | OpenWrt rootfs overlay (copied to gitignored `files/` at build time) |
| `custom/feeds.conf.append` | Appended to upstream `feeds.conf.default` after sync |
| `custom/patches/tailscale/` | Reference patches for Tailscale strip/GOGC |
| `custom/scripts/` | Mirror of build helpers (also live under `scripts/`) |
| `clean_seed.config` | Package seed: Tailscale, AdGuard, Cloudflare, Argon, NSS… |
| `seed_ipq807x_1g.config` | 1GB RAM memory profile + shared NSS knobs (any IPQ807x board) |
| `seed_tailscale_nss.config` | Optional Tailscale + NSS fragment |

## Local / CI build order

```bash
# 1) materialize rootfs overlay
rsync -a custom/files/ files/

# 2) feeds + Tailscale optimize
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/apply-tailscale-optimize.sh

# 3) config (multi-device 1GB class)
cp -f .full_config .config
cat clean_seed.config >> .config
cat seed_ipq807x_1g.config >> .config
make defconfig

# one-shot multi-device:
./scripts/build-ipq807x-1g.sh

# optional single device:
DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh
DEVICE=qnap_301w ./scripts/build-ipq807x-1g.sh
```

## Adding a new preserved file

1. Put durable content under `custom/` when possible.
2. Add the path to `custom/PRESERVE.list` (one path per line).
3. Ensure the sync workflow restores it (reads `PRESERVE.list`).
