# Fork layout (maintenance map)

Everything this fork owns lives under **`custom/`** (plus two workflow files and root `README.md`).

```text
custom/
├── PRESERVE.list          # what survives upstream sync
├── UPSTREAM_SHA           # last synced AgustinLorenzo main_nss tip
├── feeds.conf.append      # idempotent append → feeds.conf.default (src-link)
├── feed/                  # local OpenWrt feed (src-link custom_feed)
│   ├── luci-app-dns-rewrites/
│   ├── luci-app-wol-api/
│   └── udp-broadcast-relay-redux/
├── patches/               # copied onto official feeds after `prepare.sh --feeds`
│   └── avahi/             # legacy-unicast slot count
├── README.md              # short maintainer index
├── config/
│   ├── clean_seed.config  # package enable/disable (CONFIG_PACKAGE_* only)
│   ├── seed_ipq807x_1g.config
│   └── required_symbols.txt
├── files/                 # durable rootfs overlay → materialize to files/
├── scripts/
│   ├── common.sh
│   ├── prepare.sh         # overlay + feeds + Go strip + feed patches
│   ├── apply-go-optimize.sh
│   ├── build.sh
│   ├── verify-overlay.sh
│   ├── verify-config.sh
│   ├── sync-backup.sh
│   └── sync-restore.sh
└── docs/
    ├── LAYOUT.md          # this file
    ├── BUILD.md
    ├── BUILD-SAFETY.md
    ├── COMPONENTS.md
    ├── dns-rewrites.md
    └── SITE.md            # runtime / boot / SQM / DNS (no secrets)

.github/workflows/
├── build-ipq807x.yml
└── sync-upstream.yml
```

## Daily commands

```bash
./custom/scripts/prepare.sh --feeds      # overlay + feeds + Go strip + avahi patch
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
| Patch an **official feed** package | `custom/patches/<pkg>/` + copy in `prepare.sh --feeds` |
| Package enable (image) | `custom/config/clean_seed.config` (`CONFIG_PACKAGE_*=y`) |
| Platform/NSS knobs | `custom/config/seed_ipq807x_1g.config` |
| Must-have CONFIG_ check | `custom/config/required_symbols.txt` |
| Build logic | `custom/scripts/*.sh` |
| Survives sync | already under `custom/` or add path to `PRESERVE.list` |

**Feed vs seed vs overlay:** feed = source; seed = selected for the image; overlay = files on the rootfs.

**Site secrets** (Wi‑Fi keys, Gateway DoH URL, tunnel token, DHCP hosts) stay on the device (keep-settings). Do not add them under `custom/`.
