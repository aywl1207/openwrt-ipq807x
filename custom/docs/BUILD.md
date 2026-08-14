# Build guide (IPQ807x NSS + 1GB class)

## One-shot

```bash
./custom/scripts/build.sh
DEVICE=dynalink_dl-wrx36 ./custom/scripts/build.sh
```

## Config stack

```text
.full_config
  → custom/config/clean_seed.config
  → custom/config/seed_ipq807x_1g.config
  → make defconfig
```

## Step-by-step

```bash
./custom/scripts/prepare.sh --feeds     # also copies custom/patches/avahi onto the feed

# or manually:
# rsync -a custom/files/ files/
# ./scripts/feeds update -a && ./scripts/feeds install -a
# ./custom/scripts/apply-go-optimize.sh
# cp custom/patches/avahi/*.patch feeds/packages/libs/avahi/patches/

cp -f .full_config .config
cat custom/config/clean_seed.config >> .config
cat custom/config/seed_ipq807x_1g.config >> .config
make defconfig
./custom/scripts/verify-config.sh

make download -j"$(nproc)" V=s || make download V=s
make tools/install -j"$(nproc)" V=s || make tools/install V=s
make toolchain/install -j"$(nproc)" V=s || make toolchain/install V=s
make -j"$(nproc)" V=s || make -j1 V=s
```

## Upstream sync

Actions → **Sync upstream** (`sync-upstream.yml`).  
Logic: `custom/scripts/sync-backup.sh` / `sync-restore.sh` + `custom/PRESERVE.list`.
