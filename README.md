# my_linux

一个用于学习/实验的 Linux + BusyBox + QEMU 工作流仓库，支持多架构一键编译与启动。

当前支持架构：
- `x86_64`
- `arm`
- `arm64`
- `riscv`

核心目标：
- 编译仓库内 `linux/` 内核
- 生成最小可启动 `initramfs`
- 用 QEMU 直接启动
- 跨架构时自动处理交叉工具链和 BusyBox 构建（基于本仓库 `busybox/` 源码）

## 仓库结构

- `linux/`: Linux 内核源码（submodule）
- `busybox/`: BusyBox 源码（submodule）
- `qemu/`: QEMU 源码（submodule）
- `scripts/build-kernel.sh`: 内核构建脚本
- `scripts/build-busybox.sh`: BusyBox 构建脚本
- `scripts/build-qemu.sh`: QEMU 构建脚本
- `scripts/ensure-build-deps.py`: 构建依赖检查/自动安装脚本
- `scripts/build-initramfs.sh`: initramfs 打包脚本
- `scripts/run-qemu.sh`: QEMU 启动脚本
- `scripts/build-and-run-qemu.sh`: 串联构建+启动
- `Makefile`: 推荐入口

## 初始化

首次拉取后先初始化 submodule：

```bash
git submodule update --init --recursive --depth 1 linux
git submodule update --init --recursive --depth 1 busybox
git submodule update --init --recursive --depth 1 qemu
```

仓库内所有 submodule 默认按浅克隆初始化，避免把完整历史一并拉下来。

## 依赖

`scripts/build-kernel.sh`、`scripts/build-busybox.sh`、`scripts/build-qemu.sh` 和 `scripts/build-initramfs.sh` 现在会在真正编译前自动检查依赖。
如果发现缺失，会按当前系统检测到的包管理器自动安装；已支持：

- `apt-get`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`

也可以手动先跑一次：

```bash
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --arch x86_64
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --arch riscv
```

如果只想检查、不安装：

```bash
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only
```

如果你不想在构建时自动安装依赖，可以设置 `ENSURE_BUILD_DEPS=0`。

QEMU 不再通过系统包管理器安装二进制，而是使用仓库内 `qemu/` submodule 从源码构建到 `out/qemu/$ARCH/`。

下面仍保留 Debian/Ubuntu 的手动安装示例（这些是构建依赖，不包含 QEMU 二进制包）：

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential perl bc bison flex libelf-dev libssl-dev file binutils \
  cpio gzip busybox clang lld python3 python3-venv ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev
```

跨架构编译内核与 BusyBox（arm/arm64/riscv）建议安装：

```bash
sudo apt-get install -y \
  gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu \
  libc6-dev-armhf-cross libc6-dev-arm64-cross libc6-dev-riscv64-cross
```

## 快速开始

默认 `make` 走 `x86_64`：

```bash
make
```

一键跑不同架构：

```bash
make x86
make arm
make arm64
make riscv
```

上面命令会执行：
- 内核构建
- BusyBox 构建
- initramfs 构建
- QEMU 源码构建（首次或缺失时）
- QEMU 启动

BusyBox 会优先使用本仓库 `busybox/` 源码构建，输出到 `out/busybox/$ARCH/busybox`。

## 常用目标

```bash
make help
make kernel ARCH=riscv
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
make qemu ARCH=riscv
make initramfs ARCH=riscv
make run ARCH=riscv
make build-and-run ARCH=riscv
make clean ARCH=riscv
```

## 常用变量

- `ARCH`: `x86_64|arm|arm64|riscv`
- `JOBS`: 并行编译线程数
- `CROSS_COMPILE`: 交叉工具链前缀（为空时自动探测）
- `LLVM`: 设为 `1` 时使用 clang 工具链
- `BUSYBOX_BIN`: 指定 BusyBox 二进制路径（默认自动探测）
- `BUSYBOX_STATIC`: `auto|1|0`（`auto`=跨架构静态、本机架构动态）
- `QEMU_DIR`: QEMU 源码目录（默认 `qemu/`）
- `QEMU_BUILD_DIR`: QEMU 输出目录（默认 `out/qemu/$ARCH`）
- `QEMU_BIN`: 覆盖 QEMU 可执行文件路径；为空时默认使用本仓库构建产物
- `ENSURE_BUILD_DEPS`: `1|0`（默认 `1`，构建前自动检查并安装缺失依赖）
- `PYTHON_BIN`: 指定依赖检查脚本使用的 Python 解释器（默认 `python3`）
- `INITRAMFS_DIR`: initramfs 目录（默认 `out/initramfs/$ARCH`）
- `OUT_DIR`: 内核输出目录（默认 `out/$ARCH`）
- `QEMU_ARGS`: 传给 QEMU 的额外参数
- `KERNEL_CMDLINE`: 覆盖默认 kernel cmdline

示例：

```bash
make run ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- JOBS=16
make run ARCH=arm64 QEMU_ARGS="-s -S"
```

## 输出目录

- 内核：`out/$ARCH/...`
- BusyBox：`out/busybox/$ARCH/busybox`
- QEMU：`out/qemu/$ARCH/qemu-system-*`
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`

## 脚本直跑

也可以不经 Makefile，直接用脚本：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-and-run-qemu.sh
```

分步执行：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-kernel.sh
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-busybox.sh
ARCH=riscv ./scripts/build-qemu.sh
ARCH=riscv ./scripts/build-initramfs.sh
ARCH=riscv ./scripts/run-qemu.sh
```

## 故障排查

`Starting init ... error -8`：
- 一般是 BusyBox 架构不匹配（比如用 x86 BusyBox 启动 riscv 内核）。
- 解决：用目标架构 BusyBox，或直接走 `make riscv` 自动构建。

`No working init found` / `Failed to execute /init (error -2)`：
- 通常是 initramfs 中缺少动态加载器或 shell 链接损坏。
- 先重新打包：`make initramfs ARCH=<arch>`。

`byteswap.h: No such file or directory`（构建跨架构 BusyBox）：
- 缺少对应交叉 libc 头文件。
- 安装 `libc6-dev-<arch>-cross` 后重试。

`riscv64-linux-gnu-objcopy ... unsupported GNU_PROPERTY_TYPE`：
- 常见于 GNU binutils 对新属性提示 warning。
- 当前脚本在 riscv 下会优先用 `llvm-objcopy/llvm-nm` 以降低噪音。

## 说明

更多中文说明见：
- `docs/qemu_kernel_run_zh.md`
