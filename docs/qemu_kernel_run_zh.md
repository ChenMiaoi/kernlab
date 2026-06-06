# 在 QEMU 里启动模板化 Linux（x86_64 / arm / arm64 / riscv）

本仓库现在可以作为 QEMU Linux 模板使用：初始化 submodule，编辑一次 `qemu-linux.mk`，之后用 `make run` 构建并启动。

## 1. 模板入口

```bash
git submodule update --init --recursive --depth 1 linux busybox qemu
$EDITOR qemu-linux.mk
make run
```

推荐把项目默认值写进根目录 `qemu-linux.mk`。它是 Make 语法，所有字段都用 `?=`，所以命令行仍然优先：

```bash
make run ARCH=riscv MEMORY=1024 SMP=1
make run LINUX_DIR=/path/to/linux KERNEL_DEBUG=0
```

常用配置：

```make
ARCH ?= x86_64
LINUX_DIR ?= $(REPO_DIR)/linux
BUSYBOX_DIR ?= $(REPO_DIR)/busybox
QEMU_DIR ?= $(REPO_DIR)/qemu
OUT_DIR ?= $(REPO_DIR)/out/$(ARCH)
LLVM ?= 1
KERNEL_DEBUG ?= 1
MEMORY ?=
SMP ?=
KERNEL_CMDLINE ?=
QEMU_ARGS ?=
```

## 2. 外部仓库/模板复用

使用外部 Linux 源码树：

```make
LINUX_DIR ?= /home/me/src/linux
ARCH ?= arm64
CROSS_COMPILE ?= aarch64-linux-gnu-
```

使用已有 BusyBox 或 QEMU：

```make
BUSYBOX_BIN ?= /opt/arm64-rootfs/bin/busybox
QEMU_BIN ?= /usr/bin/qemu-system-aarch64
```

自定义 initramfs：

```make
INITRAMFS_HOSTNAME ?= qemu-linux
INITRAMFS_BANNER ?= == booted from my template ==
INITRAMFS_EXTRA_DIR ?= $(REPO_DIR)/rootfs-overlay
```

`INITRAMFS_EXTRA_DIR` 会在打包前复制到 rootfs 根目录。示例：`rootfs-overlay/etc/profile` 会成为 initramfs 内的 `/etc/profile`。路径不存在时脚本会直接报错。

## 3. 依赖

`scripts/build-kernel.sh`、`scripts/build-busybox.sh`、`scripts/build-qemu.sh` 和 `scripts/build-initramfs.sh` 会先自动检查依赖；缺失时会按系统可用的包管理器自动安装，当前支持 `apt-get`、`dnf`、`yum`、`pacman`、`zypper`、`apk`。

只检查不安装：

```bash
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only --llvm --kernel-debug
```

不想在构建时自动安装依赖：

```bash
make run ENSURE_BUILD_DEPS=0
```

默认内核构建使用 LLVM/Clang；如需 GCC/binutils，设置 `LLVM=0`。默认还会通过 `bear` 刷新根目录 `compile_commands.json`，方便 `clangd` 索引 `linux/`；如不需要，设置 `KERNEL_DEBUG=0`。

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

`initramfs` 里的 BusyBox 必须和目标架构一致，否则启动时会出现 `Starting init ... error -8`（`Exec format error`）。跨架构建议使用目标架构静态链接 BusyBox；`make run ARCH=<arch>` 会优先构建本仓库 `busybox/`。

## 4. 一键编译并启动

```bash
make run
make run ARCH=riscv
make arm64
```

成功后会在 QEMU 串口里看到：

- `== custom kernel booted ==`，或你在 `INITRAMFS_BANNER` 中配置的横幅
- 一个交互控制台 shell

退出方式：

```sh
reboot -f
```

## 5. 分步执行

```bash
make kernel ARCH=riscv
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
make qemu ARCH=riscv
make initramfs ARCH=riscv
make run ARCH=riscv
```

也可以直接使用脚本；脚本接受与 `qemu-linux.mk` 对应的环境变量：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-and-run-qemu.sh
```

分步脚本：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-kernel.sh
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-busybox.sh
ARCH=riscv ./scripts/build-qemu.sh
ARCH=riscv ./scripts/build-initramfs.sh
ARCH=riscv ./scripts/run-qemu.sh
```

## 6. 常用运行参数

优先写入 `qemu-linux.mk`，临时实验时用命令行覆盖：

```bash
make run JOBS=16
make run MEMORY=4096 SMP=4
make run QEMU_ARGS="-s -S"
make run KERNEL_CMDLINE="loglevel=7 printk.time=1 panic=-1 console=ttyAMA0 rdinit=/init"
```

## 7. 输出文件位置

- 内核镜像：`out/$ARCH/arch/...`
- BusyBox：`out/busybox/$ARCH/busybox`
- QEMU：`out/qemu/$ARCH/qemu-system-*`
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`
- 编译数据库：`compile_commands.json`（来自 `out/$ARCH/compile_commands.json`）
