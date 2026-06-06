# my_linux

可直接复用的 Linux + BusyBox + QEMU 模板仓库。目标体验：在自己的仓库里改一次 `qemu-linux.mk`，之后用 `make run` 构建并启动 QEMU Linux。

支持架构：`x86_64`、`arm`、`arm64`、`riscv`。

## 模板快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
cd my_linux
$EDITOR qemu-linux.mk   # 可选
make run
```

安装目录和来源都可以覆盖：

```bash
INSTALL_DIR=~/src/qemu-linux curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
REPO_URL=https://github.com/me/my_linux.git BRANCH=main INSTALL_DIR=~/src/my_linux \
  curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/my_linux/main/scripts/bootstrap.sh | bash
```

如果已经在本仓库 checkout 内，使用本地初始化入口：

```bash
./scripts/init-template.sh
make init
```

`qemu-linux.mk` 是一等配置入口，使用 Make 语法和 `?=` 默认值。常见做法是在模板仓库中提交本项目需要的默认配置；临时覆盖仍然用命令行：

```bash
make run ARCH=riscv MEMORY=1024 SMP=1
make run LINUX_DIR=/path/to/linux KERNEL_DEBUG=0
```

`make` / `make x86` / `make arm` / `make arm64` / `make riscv` 都会执行完整流程：构建内核、构建 BusyBox、生成 initramfs、构建 QEMU、启动虚拟机。

## 仓库结构

- `qemu-linux.mk`: 模板配置文件，推荐优先修改这里
- `Makefile`: 稳定入口，推荐使用 `make run`
- `linux/`: Linux 内核源码（submodule，可用 `LINUX_DIR` 指向外部源码树）
- `busybox/`: BusyBox 源码（submodule）
- `qemu/`: QEMU 源码（submodule）
- `scripts/bootstrap.sh`: curl 驱动的模板 clone + 初始化脚本
- `scripts/init-template.sh`: 本地 checkout 初始化脚本
- `scripts/build-kernel.sh`: 内核构建脚本
- `scripts/build-busybox.sh`: BusyBox 构建脚本
- `scripts/build-qemu.sh`: QEMU 构建脚本
- `scripts/build-initramfs.sh`: initramfs 打包脚本
- `scripts/run-qemu.sh`: QEMU 启动脚本
- `scripts/build-and-run-qemu.sh`: 串联构建+启动
- `scripts/ensure-build-deps.py`: 构建依赖检查/自动安装脚本

## 配置文件

优先编辑 `qemu-linux.mk`：

```make
ARCH ?= x86_64
LINUX_DIR ?= $(REPO_DIR)/linux
OUT_DIR ?= $(REPO_DIR)/out/$(ARCH)
LLVM ?= 1
KERNEL_DEBUG ?= 1
MEMORY ?=
SMP ?=
KERNEL_CMDLINE ?=
QEMU_ARGS ?=
```

常用字段：

- `ARCH`: `x86_64|arm|arm64|riscv`
- `JOBS`: 并行编译线程数
- `LINUX_DIR`: Linux 源码目录；可指向当前仓库外的内核树
- `BUSYBOX_DIR` / `BUSYBOX_OUT_DIR` / `BUSYBOX_BIN`: BusyBox 源码、输出和二进制覆盖
- `QEMU_DIR` / `QEMU_BUILD_DIR` / `QEMU_BIN`: QEMU 源码、输出和二进制覆盖
- `OUT_DIR`: 内核输出目录
- `INITRAMFS_DIR`: initramfs 输出目录
- `LLVM`: `1|0`，默认使用 LLVM/Clang；设为 `0` 使用 GCC/binutils
- `KERNEL_DEBUG`: `1|0`，默认通过 `bear` 生成/刷新 `compile_commands.json`
- `ENSURE_BUILD_DEPS`: `1|0`，默认构建前检查并安装缺失依赖
- `MEMORY` / `SMP`: QEMU 内存和 vCPU 覆盖；为空时使用架构默认值
- `KERNEL_CMDLINE`: 覆盖默认 kernel cmdline
- `QEMU_ARGS`: 追加传给 QEMU 的参数
- `INITRAMFS_HOSTNAME`: 可选 `/etc/hostname`
- `INITRAMFS_BANNER`: 可选启动横幅；默认 `== custom kernel booted ==`
- `INITRAMFS_EXTRA_DIR`: 可选 rootfs overlay，打包前复制到 initramfs 根目录

所有字段都可被命令行覆盖：`make run ARCH=arm64 LLVM=0`。

## 外部项目用法

如果你的内核源码不在本仓库的 `linux/` submodule，直接在 `qemu-linux.mk` 中指向它：

```make
LINUX_DIR ?= /home/me/src/linux
ARCH ?= riscv
CROSS_COMPILE ?= riscv64-linux-gnu-
```

如果已有目标架构 BusyBox 或系统 QEMU，也可以跳过本仓库构建产物：

```make
BUSYBOX_BIN ?= /opt/rootfs/riscv64/bin/busybox
QEMU_BIN ?= /usr/bin/qemu-system-riscv64
```

给 initramfs 加文件：

```make
INITRAMFS_HOSTNAME ?= qemu-linux
INITRAMFS_BANNER ?= == booted from my template ==
INITRAMFS_EXTRA_DIR ?= $(REPO_DIR)/rootfs-overlay
```

`rootfs-overlay` 内的路径会原样覆盖到生成的 rootfs，例如 `rootfs-overlay/etc/profile` 会变成 initramfs 的 `/etc/profile`。

## 依赖

构建脚本会在真正编译前自动检查依赖。缺失时会按当前系统检测到的包管理器自动安装；已支持：`apt-get`、`dnf`、`yum`、`pacman`、`zypper`、`apk`。

手动检查示例：

```bash
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only --llvm --kernel-debug
```

如果不想自动安装依赖：

```bash
make run ENSURE_BUILD_DEPS=0
```

Debian/Ubuntu 手动安装示例（构建依赖，不包含系统 QEMU 二进制包）：

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential perl bc bison flex libelf-dev libssl-dev file binutils bear clang lld llvm \
  cpio gzip busybox python3 python3-venv ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev
```

跨架构编译内核与 BusyBox 建议安装：

```bash
sudo apt-get install -y \
  gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu \
  libc6-dev-armhf-cross libc6-dev-arm64-cross libc6-dev-riscv64-cross
```

## 常用目标

```bash
make help
make init
make kernel ARCH=riscv
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
make qemu ARCH=riscv
make initramfs ARCH=riscv
make run ARCH=riscv
make build-and-run ARCH=riscv
make clean ARCH=riscv
```

## 脚本直跑

推荐入口是 `make run`。如需直接跑脚本，脚本也接受同一组环境变量：

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

## 输出目录

- 内核：`out/$ARCH/...`
- 内核编译数据库：`out/$ARCH/compile_commands.json`
- clangd 入口：`compile_commands.json`
- BusyBox：`out/busybox/$ARCH/busybox`
- QEMU：`out/qemu/$ARCH/qemu-system-*`
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`

手动初始化 submodule 通常只作为排障 fallback：

```bash
git submodule update --init --recursive --depth 1 linux busybox qemu
```

## 故障排查

`Starting init ... error -8`：BusyBox 架构不匹配。用目标架构 BusyBox，或直接走 `make run ARCH=<arch>` 自动构建。

`No working init found` / `Failed to execute /init (error -2)`：initramfs 缺少动态加载器或 shell 链接损坏。先重新打包：`make initramfs ARCH=<arch>`。

`byteswap.h: No such file or directory`：跨架构 BusyBox 缺少对应交叉 libc 头文件。安装 `libc6-dev-<arch>-cross` 后重试。

`riscv64-linux-gnu-objcopy ... unsupported GNU_PROPERTY_TYPE`：常见于 GNU binutils 对新属性提示 warning；脚本在 riscv 下会优先用 `llvm-objcopy/llvm-nm` 降低噪音。

更多中文说明见 `docs/qemu_kernel_run_zh.md`。
