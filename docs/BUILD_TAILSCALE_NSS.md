# IPQ807x NSS + Tailscale 本地编译指南（1GB 通用）

## 一键编译（推荐）

```bash
# 多机型（.full_config 设备集）+ 1GB 内存 profile + clean_seed 套件
./scripts/build-ipq807x-1g.sh

# 可选：只编一台
DEVICE=dynalink_dl-wrx36 ./scripts/build-ipq807x-1g.sh
DEVICE=qnap_301w ./scripts/build-ipq807x-1g.sh

# 日志: logs/build-ipq807x-1g-*.log
# 产物: bin/targets/qualcommax/ipq807x/
```

配置栈：

```text
.full_config
  → clean_seed.config          # Tailscale / AdGuard / Cloudflare / Argon / NSS…
  → seed_ipq807x_1g.config     # IPQ_MEM 1024 + 通用 NSS / ath11k
  → (可选) DEVICE=… 单机型
  → make defconfig
```

Rootfs 覆盖层权威副本在 **`custom/files/`**（`/files` 被 `.gitignore` 忽略）；构建脚本会自动 `rsync` 到 `files/`。

兼容脚本：`./scripts/build-qnap-301w.sh` 等同于 `DEVICE=qnap_301w ./scripts/build-ipq807x-1g.sh`（已弃用命名，仅作兼容）。

---

## 本仓库 workflow 概览

| 文件 | 作用 |
|------|------|
| `feeds.conf.default` | 软件源：packages / luci / **nss_packages** / sqm-nss / qosmio |
| `.full_config` | 上游 NSS multi-device 完整基底 |
| `clean_seed.config` | 自订叠加：套件开关 |
| `seed_ipq807x_1g.config` | 1GB RAM + 通用 NSS 旋钮 |
| `scripts/apply-tailscale-optimize.sh` | Tailscale `-s -w` 与 `GOGC=10` |
| `custom/files/` | 首次启动 NSS/Tailscale QoL、优化后的 init |

---

## Tailscale 体积 / 记忆体优化

```bash
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install tailscale
./scripts/apply-tailscale-optimize.sh
```

- **Makefile**：`GO_PKG_LDFLAGS` 注入 `-s -w`
- **init**：`procd` 环境 `GOGC=10`

---

## 手动配置步骤

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

### 刷机后检查

```bash
# NSS：须关闭 SW flow offload
uci show firewall | grep flow_offloading
lsmod | grep -E 'qca_nss|ecm'

# Tailscale GOGC
tr '\0' '\n' < /proc/$(pidof tailscaled)/environ | grep GOGC
tailscale up
```

---

## Upstream sync protection (manual, only when upstream changes)

`.github/workflows/sync_fork_with_customization.yaml` is **workflow_dispatch only**
(no weekly schedule). It:

1. Compares `upstream/main_nss` with `custom/UPSTREAM_SHA` — **skips if unchanged**
2. Backs up every path in `custom/PRESERVE.list`
3. `git reset --hard upstream/main_nss`
4. Restores those paths (including entire `custom/` tree)
5. Writes the new tip to `custom/UPSTREAM_SHA`
6. Materializes `custom/files/` → gitignored `files/`
7. Re-clones luci-theme-argon

Force a re-sync from Actions with input **force=true**.

**Do not put durable customizations only under `/files`** (gitignored).  
Use `custom/files/` and add new paths to `custom/PRESERVE.list`.
