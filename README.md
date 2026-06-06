# kernlab

Linux-first QEMU workspace bootstrap for editing a local Linux source tree and validating it quickly with BusyBox + QEMU.

支持架构：`x86_64`、`arm`、`arm64`、`riscv`。

## 快速开始

推荐入口是 npm 初始化器，不依赖 GitHub raw URL：

```bash
npx create-kernlab
$EDITOR linux/          # 主要编辑区：Linux 内核源码
$EDITOR qemu-linux.mk   # 可选：构建/运行配置
make run
```

也可以使用 npm create 形式：

```bash
npm create kernlab@latest
```

默认会把当前目录初始化为工作区顶层：

```text
./
  linux/              # 用户主要编辑的 Linux 源码树
  .kernlab/   # 模板、脚本、BusyBox、QEMU；通常不编辑
  qemu-linux.mk       # 工作区本地配置
  Makefile            # 委托到模板；在工作区根目录运行 make run
```

如果想从别的位置创建工作区，可以把安装目录作为位置参数或 `--dir` 传入：

```bash
npx create-kernlab ~/src/my-kernel
npx create-kernlab --dir ~/src/my-kernel
```

使用已有 Linux checkout/fork：

```bash
npx create-kernlab --linux-dir /home/me/src/linux
```

从指定 Linux fork/branch 克隆到工作区 `linux/`：

```bash
npx create-kernlab --linux-url https://github.com/me/linux.git --linux-branch my-topic
```

如果 npm 包还没发布，或者你是在开发这个模板仓库本身，使用本地初始化入口：

```bash
node ./bin/create-kernlab.js --help
./scripts/init-template.sh
make init
```

curl 入口仍然保留给公开 GitHub 仓库使用：

```bash
curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/kernlab/main/scripts/bootstrap.sh | bash
```

`qemu-linux.mk` 是一等配置入口，使用 Make 语法和 `?=` 默认值。常见做法是在工作区根目录的 `qemu-linux.mk` 写入本地默认配置；临时覆盖仍然用命令行：

```bash
make run ARCH=riscv MEMORY=1024 SMP=1
make run LINUX_DIR=/path/to/linux KERNEL_DEBUG=0
```

`make` / `make x86` / `make arm` / `make arm64` / `make riscv` 都会执行完整流程：构建内核、构建 BusyBox、生成 initramfs、构建 QEMU、启动虚拟机。

## 工作区与模板边界

工作区根目录是面向使用者的入口：

- `linux/`: Linux 内核源码。这里是主要工作树，可以替换成自己的 fork 或用 `LINUX_DIR` 指向外部源码树。
- `qemu-linux.mk`: 工作区本地配置文件，推荐优先修改这里。
- `Makefile`: 工作区 wrapper，保留 `make run`、`make kernel`、`make qemu` 等入口。
- `out/`: 工作区构建输出。

`.kernlab/` 是支持基础设施：

- `busybox/`: BusyBox 源码（submodule）。
- `qemu/`: QEMU 源码（submodule）。
- `scripts/bootstrap.sh`: curl 驱动的工作区创建脚本。
- `scripts/init-template.sh`: 模板仓库本地 checkout 初始化脚本。
- `scripts/build-kernel.sh`: 内核构建脚本。
- `scripts/build-busybox.sh`: BusyBox 构建脚本。
- `scripts/build-qemu.sh`: QEMU 构建脚本。
- `scripts/build-initramfs.sh`: initramfs 打包脚本。
- `scripts/run-qemu.sh`: QEMU 启动脚本。
- `scripts/build-and-run-qemu.sh`: 串联构建+启动。
- `scripts/ensure-build-deps.py`: 构建依赖检查/自动安装脚本。

通常只编辑工作区的 `linux/` 和 `qemu-linux.mk`。只有在开发模板功能时才进入 `.kernlab/`。

## 配置文件

工作区生成的 `qemu-linux.mk` 会把 Linux、BusyBox、QEMU 和输出目录分开：

```make
TEMPLATE_DIR := $(CURDIR)/.kernlab
LINUX_DIR ?= $(CURDIR)/linux
BUSYBOX_DIR ?= $(TEMPLATE_DIR)/busybox
QEMU_DIR ?= $(TEMPLATE_DIR)/qemu
OUT_DIR ?= $(CURDIR)/out/$(ARCH)
INITRAMFS_DIR ?= $(CURDIR)/out/initramfs/$(ARCH_CANON)
BUSYBOX_OUT_DIR ?= $(CURDIR)/out/busybox/$(ARCH_CANON)
QEMU_BUILD_DIR ?= $(CURDIR)/out/qemu/$(ARCH_CANON)
```

常用字段：

- `ARCH`: `x86_64|arm|arm64|riscv`
- `JOBS`: 并行编译线程数
- `LINUX_DIR`: Linux 源码目录；可指向工作区外的内核树
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

如果你的内核源码不在工作区 `linux/`，直接在 `qemu-linux.mk` 中指向它：

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
INITRAMFS_EXTRA_DIR ?= $(CURDIR)/rootfs-overlay
```

`rootfs-overlay` 内的路径会原样覆盖到生成的 rootfs，例如 `rootfs-overlay/etc/profile` 会变成 initramfs 的 `/etc/profile`。

## 依赖

构建脚本会在真正编译前自动检查依赖。缺失时会按当前系统检测到的包管理器自动安装；已支持：`apt-get`、`dnf`、`yum`、`pacman`、`zypper`、`apk`。

手动检查示例：

```bash
python3 .kernlab/scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only --llvm --kernel-debug
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

## 发布 npm 初始化器

仓库已包含可发布包 `create-kernlab`。发布前先检查包内容：

```bash
npm pack --dry-run
npm publish --access public
```

发布后用户可以直接运行：

```bash
npx create-kernlab@latest
npm create kernlab@latest
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

推荐入口是工作区根目录的 `make run`。如需直接跑脚本，脚本也接受同一组环境变量：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .kernlab/scripts/build-and-run-qemu.sh
```

分步执行：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .kernlab/scripts/build-kernel.sh
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .kernlab/scripts/build-busybox.sh
ARCH=riscv .kernlab/scripts/build-qemu.sh
ARCH=riscv .kernlab/scripts/build-initramfs.sh
ARCH=riscv .kernlab/scripts/run-qemu.sh
```

## 输出目录

- 内核：`out/$ARCH/...`
- 内核编译数据库：`out/$ARCH/compile_commands.json`
- clangd 入口：`.kernlab/compile_commands.json`
- BusyBox：`out/busybox/$ARCH/busybox`
- QEMU：`out/qemu/$ARCH/qemu-system-*`
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`

手动刷新模板支持仓库通常只作为排障 fallback：

```bash
make init
```

## 故障排查

`Starting init ... error -8`：BusyBox 架构不匹配。用目标架构 BusyBox，或直接走 `make run ARCH=<arch>` 自动构建。

`No working init found` / `Failed to execute /init (error -2)`：initramfs 缺少动态加载器或 shell 链接损坏。先重新打包：`make initramfs ARCH=<arch>`。

`byteswap.h: No such file or directory`：跨架构 BusyBox 缺少对应交叉 libc 头文件。安装 `libc6-dev-<arch>-cross` 后重试。

`riscv64-linux-gnu-objcopy ... unsupported GNU_PROPERTY_TYPE`：常见于 GNU binutils 对新属性提示 warning；脚本在 riscv 下会优先用 `llvm-objcopy/llvm-nm` 降低噪音。

更多中文说明见 `docs/qemu_kernel_run_zh.md`。
