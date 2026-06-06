# 在 QEMU 里启动工作区 Linux（x86_64 / arm / arm64 / riscv）

本模板的默认入口是 Linux-first 工作区：`linux/` 是用户主要编辑的内核源码，QEMU/BusyBox/脚本放在隐藏的 `.qemu-kernel-lab/` 支持目录里。

## 1. 工作区入口

推荐入口是 npm 初始化器，不依赖 GitHub raw URL：

```bash
npx create-qemu-kernel-lab
cd qemu-kernel-lab
$EDITOR linux/          # 主要编辑区：Linux 内核源码
$EDITOR qemu-linux.mk   # 可选：构建/运行配置
make run
```

也可以使用 npm create 形式：

```bash
npm create qemu-kernel-lab@latest
```

默认结构：

```text
qemu-kernel-lab/
  linux/              # 用户主要编辑的 Linux 源码树
  .qemu-kernel-lab/   # 模板、脚本、BusyBox、QEMU；通常不编辑
  qemu-linux.mk       # 工作区本地配置
  Makefile            # 委托到模板；在工作区根目录运行 make run
```

覆盖安装目录：

```bash
npx create-qemu-kernel-lab ~/src/kernel-lab
npx create-qemu-kernel-lab --dir ~/src/kernel-lab
```

使用已有 Linux checkout/fork：

```bash
npx create-qemu-kernel-lab --linux-dir /home/me/src/linux
```

从指定 Linux fork/branch 克隆到工作区 `linux/`：

```bash
npx create-qemu-kernel-lab --linux-url https://github.com/me/linux.git --linux-branch my-topic
```

如果 npm 包还没发布，或者已经 clone 了模板仓库并且是在开发模板本身，用本地入口：

```bash
node ./bin/create-qemu-kernel-lab.js --help
./scripts/init-template.sh
make init
```

curl 入口仍然保留给公开 GitHub 仓库使用：

```bash
curl -fsSL https://raw.githubusercontent.com/ChenMiaoi/qemu-kernel-lab/main/scripts/bootstrap.sh | bash
```

推荐把项目默认值写进工作区根目录 `qemu-linux.mk`。它是 Make 语法，所有字段都用 `?=`，所以命令行仍然优先：

```bash
make run ARCH=riscv MEMORY=1024 SMP=1
make run LINUX_DIR=/path/to/linux KERNEL_DEBUG=0
```

常用配置：

```make
TEMPLATE_DIR := $(CURDIR)/.qemu-kernel-lab
LINUX_DIR ?= $(CURDIR)/linux
BUSYBOX_DIR ?= $(TEMPLATE_DIR)/busybox
QEMU_DIR ?= $(TEMPLATE_DIR)/qemu
OUT_DIR ?= $(CURDIR)/out/$(ARCH)
INITRAMFS_DIR ?= $(CURDIR)/out/initramfs/$(ARCH_CANON)
BUSYBOX_OUT_DIR ?= $(CURDIR)/out/busybox/$(ARCH_CANON)
QEMU_BUILD_DIR ?= $(CURDIR)/out/qemu/$(ARCH_CANON)
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
INITRAMFS_EXTRA_DIR ?= $(CURDIR)/rootfs-overlay
```

`INITRAMFS_EXTRA_DIR` 会在打包前复制到 rootfs 根目录。示例：`rootfs-overlay/etc/profile` 会成为 initramfs 内的 `/etc/profile`。路径不存在时脚本会直接报错。

## 3. 工作区边界

- `linux/`：主要工作树。内核改动放这里，或者用 `LINUX_DIR` 指向外部 Linux checkout。
- `qemu-linux.mk`：工作区本地构建/运行配置。
- `Makefile`：工作区 wrapper，保留 `make run`、`make kernel`、`make qemu` 等入口。
- `out/`：工作区构建输出。
- `.qemu-kernel-lab/`：模板支持目录，包含 `busybox/`、`qemu/`、`scripts/` 和模板 Makefile；通常不要在内核实验中修改它。

## 4. 依赖

`.qemu-kernel-lab/scripts/build-kernel.sh`、`build-busybox.sh`、`build-qemu.sh` 和 `build-initramfs.sh` 会先自动检查依赖；缺失时会按系统可用的包管理器自动安装，当前支持 `apt-get`、`dnf`、`yum`、`pacman`、`zypper`、`apk`。

只检查不安装：

```bash
python3 .qemu-kernel-lab/scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only --llvm --kernel-debug
```

不想在构建时自动安装依赖：

```bash
make run ENSURE_BUILD_DEPS=0
```

默认内核构建使用 LLVM/Clang；如需 GCC/binutils，设置 `LLVM=0`。默认还会通过 `bear` 刷新 `.qemu-kernel-lab/compile_commands.json`，方便 `clangd` 索引；如不需要，设置 `KERNEL_DEBUG=0`。

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

`initramfs` 里的 BusyBox 必须和目标架构一致，否则启动时会出现 `Starting init ... error -8`（`Exec format error`）。跨架构建议使用目标架构静态链接 BusyBox；`make run ARCH=<arch>` 会优先构建工作区 `out/busybox/<arch>/busybox`。

## 5. 发布 npm 初始化器

仓库已包含可发布包 `create-qemu-kernel-lab`。发布前先检查包内容：

```bash
npm pack --dry-run
npm publish --access public
```

发布后用户可以直接运行：

```bash
npx create-qemu-kernel-lab@latest
npm create qemu-kernel-lab@latest
```

## 6. 一键编译并启动

```bash
make init
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

## 7. 分步执行

```bash
make kernel ARCH=riscv
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
make qemu ARCH=riscv
make initramfs ARCH=riscv
make run ARCH=riscv
```

手动刷新模板支持仓库通常只作为排障 fallback：

```bash
make init
```

也可以直接使用脚本；脚本接受与 `qemu-linux.mk` 对应的环境变量：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .qemu-kernel-lab/scripts/build-and-run-qemu.sh
```

分步脚本：

```bash
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .qemu-kernel-lab/scripts/build-kernel.sh
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- .qemu-kernel-lab/scripts/build-busybox.sh
ARCH=riscv .qemu-kernel-lab/scripts/build-qemu.sh
ARCH=riscv .qemu-kernel-lab/scripts/build-initramfs.sh
ARCH=riscv .qemu-kernel-lab/scripts/run-qemu.sh
```

## 8. 常用运行参数

优先写入 `qemu-linux.mk`，临时实验时用命令行覆盖：

```bash
make run JOBS=16
make run MEMORY=4096 SMP=4
make run QEMU_ARGS="-s -S"
make run KERNEL_CMDLINE="loglevel=7 printk.time=1 panic=-1 console=ttyAMA0 rdinit=/init"
```

## 9. 输出文件位置

- 内核镜像：`out/$ARCH/arch/...`
- BusyBox：`out/busybox/$ARCH/busybox`
- QEMU：`out/qemu/$ARCH/qemu-system-*`
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`
- 编译数据库：`.qemu-kernel-lab/compile_commands.json`（来自 `out/$ARCH/compile_commands.json`）