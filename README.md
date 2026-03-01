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
- `scripts/build-kernel.sh`: 内核构建脚本
- `scripts/build-busybox.sh`: BusyBox 构建脚本
- `scripts/build-initramfs.sh`: initramfs 打包脚本
- `scripts/run-qemu.sh`: QEMU 启动脚本
- `scripts/build-and-run-qemu.sh`: 串联构建+启动
- `Makefile`: 推荐入口

## 初始化

首次拉取后先初始化 submodule：

```bash
git submodule update --init --recursive
```

## 依赖

以 Debian/Ubuntu 为例：

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential bc bison flex libelf-dev libssl-dev \
  cpio gzip qemu-system-x86 qemu-system-arm qemu-system-misc \
  busybox clang lld
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
- initramfs 构建
- QEMU 启动

其中跨架构（`arm/arm64/riscv`）会自动先构建对应架构 BusyBox（输出到 `out/busybox/$ARCH`）。

## 常用目标

```bash
make help
make kernel ARCH=riscv
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
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
