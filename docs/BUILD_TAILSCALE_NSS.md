# IPQ807x NSS + Tailscale build notes (1GB class)

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
| `scripts/apply-tailscale-optimize.sh` | Binary strip + `GOGC=10` |

## Manual steps

```bash
rsync -a custom/files/ files/
./scripts/feeds update -a && ./scripts/feeds install -a
./scripts/apply-tailscale-optimize.sh

cp -f .full_config .config
cat clean_seed.config >> .config
cat seed_ipq807x_1g.config >> .config
make defconfig

make download -j"$(nproc)" V=s || make download V=s
make tools/install -j"$(nproc)" V=s || make tools/install V=s
make toolchain/install -j"$(nproc)" V=s || make toolchain/install V=s
make -j"$(nproc)" V=s || make -j1 V=s
```

## Upstream sync

Manual Actions workflow only; runs when `upstream/main_nss` ≠ `custom/UPSTREAM_SHA`.
See `custom/README.md` and `custom/PRESERVE.list`.
