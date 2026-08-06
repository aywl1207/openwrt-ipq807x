# Build / flash safety (QNAP 301w)

## Known failures (fixed in seed + scripts)

| Issue | Symptom | Fix |
|-------|---------|-----|
| DEVICE_PACKAGES left as `=m` | RO root (`board.json` RO), NSS/ath11k `error -12`, no WiFi board data | `force_device_rootfs_packages` after defconfig; seed `=y` for `ipq-wifi-qnap_301w`, f2fs |
| SQM auto-start + IFB delete | Reboot loop ~50s after boot (`act_nssmirred` panic) | SQM **default disabled**; `nss-zk.qos` never `ip link del ifb`; disable stock `11-sqm` hotplug race |
| pstore COMBINED.txt multi‑100MB | Overlay 100% full → settings not saved | `pstore-save` size caps + prune |
| status-push | Optional, device-only | **Not** in image; put under `/etc/status-push.sh` + sysupgrade.conf on device |

## Full build

```bash
# Multi-device CI style (no DEVICE=)
./custom/scripts/build.sh

# Or single device
DEVICE=qnap_301w ./custom/scripts/build.sh
```

`prepare.sh --config` / `build.sh` both: merge seeds → defconfig → **force packages → defconfig again** → verify-config + verify-overlay.

## After flash

1. Prefer **Keep settings** only if previous image was healthy.
2. After bad/local broken image: **`sysupgrade -n`** (no keep).
3. SQM stays **off** until you enable in LuCI and set rates.
4. Restore status-push yourself to `/etc/status-push.sh` if needed.
