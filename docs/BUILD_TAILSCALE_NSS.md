# IPQ807x NSS + Tailscale build notes (1GB class)

## Upstream base

- Tree: [AgustinLorenzo/openwrt](https://github.com/AgustinLorenzo/openwrt) `main_nss`
- Last synced SHA: see `custom/UPSTREAM_SHA`
- Sync: Actions → **Sync Fork** (only when upstream moved, or `force=true`)

## One-shot build

```bash
./scripts/build-ipq807x-1g.sh
DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh   # optional single board
```

Config stack:

```text
.full_config → clean_seed.config → seed_ipq807x_1g.config → make defconfig
```

| File | Role |
|------|------|
| `clean_seed.config` | Packages (Tailscale, AdGuard, Cloudflare, Argon, NSS crypto, …) |
| `seed_ipq807x_1g.config` | `IPQ_MEM_PROFILE_1024` + shared NSS / ath11k knobs |
| `custom/files/` | Rootfs overlay (init + first-boot QoL) |
| `scripts/apply-component-optimize.sh` | Go packages `-s -w` + all component overlays |

## Preserved components (do not drop on sync)

| Category | Packages / assets |
|----------|-------------------|
| VPN | `tailscale` (`-s -w`, `GOGC=10`, `GOMEMLIMIT=128MiB`) |
| DNS | `adguardhome` (**auto-start**, primary DNS provider) |
| Tunnel | `cloudflared`, `luci-app-cloudflared` |
| NSS | `kmod-qca-nss-drv/ecm/dp/crypto`, managers, `nss-eip-firmware`, FW 12.5 |
| SQM | `sqm-scripts`, `sqm-scripts-nss`, `luci-app-sqm` |
| UI | LuCI + `luci-theme-argon`, `zh_Hant` / `*-zh-tw` |
| Utils | Cloudflare DDNS, mdns-repeater, udp-broadcast-relay-redux, drill, ipset |
| RAM | `zram-swap`, `kmod-zram`, `haveged` |

## Manual steps

```bash
rsync -a custom/files/ files/
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/apply-component-optimize.sh

cp -f .full_config .config
cat clean_seed.config >> .config
cat seed_ipq807x_1g.config >> .config
make defconfig

make download -j"$(nproc)" V=s || make download V=s
make tools/install -j"$(nproc)" V=s || make tools/install V=s
make toolchain/install -j"$(nproc)" V=s || make toolchain/install V=s
make -j"$(nproc)" V=s || make -j1 V=s
```

## Tailscale feed note

Tailscale ships in the official `packages` feed (`net/tailscale`).  
`custom/feeds.conf.append` only documents this — no extra `src-git` required.

```bash
# Optional local echo (documentation only; already applied after sync):
# cat custom/feeds.conf.append >> feeds.conf.default
```

## Upstream sync

Manual Actions workflow only; runs when `upstream/main_nss` ≠ `custom/UPSTREAM_SHA`.  
See `custom/README.md` and `custom/PRESERVE.list`.
