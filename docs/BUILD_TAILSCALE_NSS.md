# IPQ807x NSS + Tailscale 本地编译指南

## QNAP QHora-301W 一键编译

```bash
./scripts/build-qnap-301w.sh
# 日志: logs/build-qnap-301w-*.log
# 产物: bin/targets/qualcommax/ipq807x/*301w*
```

配置栈：`.full_config` → `clean_seed.config`（保留全部组件）→ `seed_qnap_301w.config`（单机型 + 1GB mem + f2fs/board）。

Rootfs 覆盖层的权威副本在 **`custom/files/`**（`/files` 被 `.gitignore` 忽略）；构建脚本会自动 `rsync` 到 `files/`。

---

本文对应本仓库 `custom_main_nss` 分支的实际 workflow：

| 文件 | 作用 |
|------|------|
| `feeds.conf.default` | 软件源：packages / luci / **nss_packages** / sqm-nss / qosmio |
| `.full_config` | 上游 NSS multi-device 完整基底（含 kmod-qca-nss-drv/ecm 等） |
| `clean_seed.config` | 自订叠加：精简无用包、加 AdGuard/Cloudflare/Argon/Tailscale、NSS FW 12.5 |
| `seed_tailscale_nss.config` | 可单独追加的 Tailscale + NSS 核心 seed 片段 |
| `scripts/apply-tailscale-optimize.sh` | 对 feeds 中的 tailscale 注入 `-s -w` 与 `GOGC=10` |
| `files/etc/init.d/tailscale` | rootfs 覆盖：保证运行时带 `GOGC=10` |

编译流水线（与 `.github/workflows/custom_ipq807x.yml` 一致）：

```text
feeds update/install
  → cp .full_config .config
  → cat clean_seed.config >> .config
  → make defconfig
  → make -j$(nproc)
```

---

## 0. 主机依赖（Ubuntu/Debian）

```bash
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses5-dev libssl-dev \
  python3-setuptools rsync swig unzip zlib1g-dev file wget \
  libelf-dev ecj fastjar java-propose-classpath python3 python3-dev
```

可选：预取上游 LLVM-BPF（与 CI 相同，加快 eBPF 相关构建）：

```bash
wget https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/llvm-bpf-22.1.3.Linux-x86_64.tar.zst
tar --zstd -xvf llvm-bpf-22.1.3.Linux-x86_64.tar.zst
```

---

## 1. Task 1 — feeds 与 Tailscale 源

Tailscale **已包含在** 官方 `packages` feed（`net/tailscale`），`feeds.conf.default` 第一行即是：

```text
src-git packages https://github.com/openwrt/packages.git
```

文件末尾已增加说明注释。若你仍想用 `echo` 追加一行说明（幂等、仅文档）：

```bash
printf '\n# Tailscale: provided by packages feed (net/tailscale); run ./scripts/apply-tailscale-optimize.sh after feeds install\n' >> feeds.conf.default
```

> 不要再 `src-git` 一份重复的 packages，会与现有源冲突。

---

## 2. Task 2 — 体积 / 记忆体优化

### 2.1 自动脚本（推荐）

```bash
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install tailscale
chmod +x scripts/apply-tailscale-optimize.sh
./scripts/apply-tailscale-optimize.sh
```

脚本会：

1. 在 `GO_PKG_LDFLAGS` 注入 **`-s -w`**（去掉符号与 DWARF）
2. 在 `tailscale.init` 的 procd 环境加入 **`GOGC=10`**
3. 同步到 `files/etc/init.d/tailscale`（镜像打包时最后覆盖）

### 2.2 手动 Makefile 要点

在 `feeds/packages/net/tailscale/Makefile`（或 `package/feeds/packages/tailscale/Makefile`）：

```make
GO_PKG_LDFLAGS:=-s -w -X 'tailscale.com/version.longStamp=$(PKG_VERSION)-$(PKG_RELEASE) (OpenWrt)'
```

官方已启用多项 `ts_omit_*` build tags，进一步减小体积，请保留。

### 2.3 手动 init 要点

```sh
procd_set_param env TS_DEBUG_FIREWALL_MODE="$fw_mode" GOGC=10
procd_append_param env GOGC=10
```

设备上热修（已刷机）：

```bash
# 编辑 /etc/init.d/tailscale，加入 GOGC=10 后：
/etc/init.d/tailscale restart
# 观察 RSS
ps w | grep tailscaled
cat /proc/$(pidof tailscaled)/status | grep -E 'VmRSS|VmSize'
```

---

## 3. Task 3 — 生成 .config

```bash
# 与 CI 相同
cp -f .full_config .config
cat clean_seed.config >> .config
# 可选再叠一层显式片段（clean_seed 已含 tailscale/nss-crypto 时可省略）
# cat seed_tailscale_nss.config >> .config

make defconfig

# 抽查关键符号
grep -E 'CONFIG_PACKAGE_tailscale=|CONFIG_PACKAGE_kmod-qca-nss-drv=|CONFIG_PACKAGE_kmod-qca-nss-ecm=|CONFIG_PACKAGE_kmod-qca-nss-crypto=|CONFIG_ATH11K_NSS_SUPPORT=' .config
```

期望输出包含：

```text
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y
CONFIG_ATH11K_NSS_SUPPORT=y
```

### Seed 核心片段（可直接追加）

见仓库根目录 `seed_tailscale_nss.config`，摘要：

```text
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y
CONFIG_PACKAGE_nss-eip-firmware=y
CONFIG_NSS_FIRMWARE_VERSION_12_5=y
CONFIG_NSS_DRV_CRYPTO_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y
CONFIG_ATH11K_NSS_SUPPORT=y
CONFIG_PACKAGE_zram-swap=y
```

---

## 4. Task 4 — 完整本地编译命令顺序

```bash
cd /path/to/openwrt-ipq807x

# --- Feeds ---
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install tailscale

# --- Tailscale 体积/内存补丁 ---
./scripts/apply-tailscale-optimize.sh

# --- 配置 ---
cp -f .full_config .config
cat clean_seed.config >> .config
make defconfig

# --- 首次启动 QoL（与 CI 对齐；可重复执行）---
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-qol_fixes << 'EOF'
uci set wireless.radio0.country='US'
uci set wireless.radio1.country='US'
uci set wireless.radio2.country='US'
uci set wireless.radio1.disabled=0
uci set wireless.radio2.disabled=0
uci set pbuf.opt.memory_profile=auto
uci set firewall.@defaults[0].flow_offloading=0
uci set firewall.@defaults[0].flow_offloading_hw=0
uci set ecm.@general[0].enable_bridge_filtering=0
uci set system.@system[0].cronloglevel='7'
uci commit wireless
uci commit pbuf
uci commit firewall
uci commit ecm
uci commit system
/etc/init.d/sqm stop 2>/dev/null || true
/etc/init.d/sqm disable 2>/dev/null || true
EOF
chmod +x files/etc/uci-defaults/99-qol_fixes

# --- 下载源码（失败时串行重试）---
make download -j"$(nproc)" V=s || make download V=s

# --- 工具链（可分步，便于排错）---
make tools/install -j"$(nproc)" V=s || make tools/install V=s
make toolchain/install -j"$(nproc)" V=s || make toolchain/install V=s

# --- 全量编译（并行；失败再串行 + 详细日志）---
make -j"$(nproc)" V=s || make -j1 V=s
```

产物目录：

```text
bin/targets/qualcommax/ipq807x/
```

### 常用排错

| 场景 | 命令 |
|------|------|
| 只重编 tailscale | `make package/tailscale/{clean,compile} V=s` |
| 只重编 NSS 驱动 | `make package/kernel/qca-nss-drv/{clean,compile} V=s`（路径以 feeds 为准） |
| 详细日志 | `V=s` 或 `V=sc` |
| 单线程定位 | `make -j1 V=s` |
| 配置菜单 | `make menuconfig` → Network → VPN → tailscale |
| 清理包 | `make package/tailscale/clean` |
| 核数 | `-j$(nproc)`；内存吃紧用 `-j$(nproc)/2` |

### 刷机后验证 NSS / Tailscale

```bash
# NSS
dmesg | grep -i nss
lsmod | grep -E 'qca_nss|ecm|ath11k'
cat /sys/kernel/debug/qca-nss-drv/stats/cpu_load_ubi 2>/dev/null || true

# 禁止与 NSS 抢 offload 的软件流卸载应保持关闭
uci show firewall | grep flow_offloading

# Tailscale
/etc/init.d/tailscale enable
/etc/init.d/tailscale start
tailscale up
# 确认 GOGC
tr '\0' '\n' < /proc/$(pidof tailscaled)/environ | grep GOGC
```

> **重要**：使用 ECM/NSS 时务必关闭 OpenWrt 软件/硬件 Flow Offloading（`flow_offloading` / `flow_offloading_hw`），否则与 ECM 冲突导致断流或无加速。本仓库 CI 的 `99-qol_fixes` 已处理。

---

## 5. 变更文件清单

| 路径 | 说明 |
|------|------|
| `feeds.conf.default` | Tailscale 说明注释 |
| `clean_seed.config` | `tailscale=y`、`kmod-qca-nss-crypto=y`、核心 NSS 重申 |
| `seed_tailscale_nss.config` | 可独立追加的 seed 片段 |
| `scripts/apply-tailscale-optimize.sh` | 补丁应用脚本 |
| `patches/tailscale/*.patch` | 参考 diff |
| `files/etc/init.d/tailscale` | `GOGC=10` 启动脚本覆盖 |
| `docs/BUILD_TAILSCALE_NSS.md` | 本文 |

---

## Weekly upstream sync protection

`.github/workflows/sync_fork_with_customization.yaml` runs weekly and:

1. Backs up every path in `custom/PRESERVE.list`
2. `git reset --hard upstream/main_nss`
3. Restores those paths (including entire `custom/` tree)
4. Materializes `custom/files/` → gitignored `files/`
5. Re-clones luci-theme-argon

**Do not put durable customizations only under `/files`** (gitignored).  
Use `custom/files/` and add new paths to `custom/PRESERVE.list`.
