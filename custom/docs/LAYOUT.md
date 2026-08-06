# Fork layout (maintenance map)

Everything this fork owns lives under **`custom/`** (plus two workflow files and root `README.md`).

```text
custom/
├── PRESERVE.list          # what survives upstream sync
├── UPSTREAM_SHA           # last synced AgustinLorenzo main_nss tip
├── feeds.conf.append      # idempotent append → feeds.conf.default (src-link)
├── feed/                  # local OpenWrt feed (src-link custom_feed)
│   └── luci-app-dns-rewrites/
├── README.md              # short maintainer index
├── config/
│   ├── clean_seed.config  # package enable/disable (CONFIG_PACKAGE_* only)
│   ├── seed_ipq807x_1g.config
│   └── required_symbols.txt   # CI/build verify list (single source)
├── files/                 # durable rootfs overlay → materialize to files/
├── scripts/
│   ├── common.sh          # paths + shared helpers
│   ├── prepare.sh         # overlay + feeds + optional defconfig
│   ├── apply-go-optimize.sh
│   ├── build.sh           # full firmware build entrypoint
│   ├── verify-overlay.sh
│   ├── verify-config.sh
│   ├── sync-backup.sh     # used by sync-upstream workflow
│   └── sync-restore.sh
└── docs/
    ├── LAYOUT.md          # this file
    ├── BUILD.md
    ├── COMPONENTS.md
    └── SITE.md            # runtime / boot / SQM / AGH (no secrets)

.github/workflows/
├── build-ipq807x.yml      # self-hosted image build (calls custom/scripts)
└── sync-upstream.yml      # reset to upstream + restore custom/

# Thin compatibility wrappers (optional; recreated logic is in custom/scripts)
scripts/build-ipq807x-1g.sh          → custom/scripts/build.sh
scripts/apply-component-optimize.sh  → custom/scripts/apply-go-optimize.sh
```

## Daily commands

```bash
./custom/scripts/prepare.sh --feeds      # overlay + feeds + Go strip
./custom/scripts/prepare.sh --config     # + defconfig + verify
./custom/scripts/build.sh                # full build
DEVICE=dynalink_dl-wrx36 ./custom/scripts/build.sh
```

## Upstream sync

1. Actions → **Sync upstream** (`sync-upstream.yml`)
2. Backs up `PRESERVE.list` paths → `git reset --hard upstream/main_nss` → restore
3. Updates `custom/UPSTREAM_SHA`
4. Re-clones `luci-theme-argon` into `package/`

## Adding a new customization

| Kind | Where |
|------|--------|
| Rootfs file / init / uci-defaults | `custom/files/...` |
| **New package source** | `custom/feed/<pkg>/` + `feeds.conf.append` `src-link` |
| Package enable (image) | `custom/config/clean_seed.config` (`CONFIG_PACKAGE_*=y`) |
| Platform/NSS knobs | `custom/config/seed_ipq807x_1g.config` |
| Must-have CONFIG_ check | `custom/config/required_symbols.txt` |
| Build logic | `custom/scripts/*.sh` |
| Survives sync | already under `custom/` or add path to `PRESERVE.list` |

**Feed vs seed:** the **feed** supplies package source; the **seed** only selects packages for the image.
