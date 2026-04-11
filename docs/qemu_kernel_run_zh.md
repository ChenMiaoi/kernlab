# 在 QEMU 里启动本仓库编译的 Linux 内核（x86_64 / arm / arm64 / riscv）

下面这套流程会使用仓库里的 `linux/` 源码编译内核镜像，再配一个最小 `initramfs`，最后用 QEMU 启动。

## 1. 依赖

`scripts/build-kernel.sh`、`scripts/build-busybox.sh`、`scripts/build-qemu.sh` 和 `scripts/build-initramfs.sh` 会先自动检查依赖；
缺失时会按系统可用的包管理器自动安装，当前支持 `apt-get`、`dnf`、`yum`、`pacman`、`zypper`、`apk`。

如果你只想先检查：

```bash
python3 ./scripts/ensure-build-deps.py --component kernel --component busybox --component qemu --component initramfs --check-only
```

如果你不想在构建时自动安装依赖，可设置 `ENSURE_BUILD_DEPS=0`。

QEMU 不再通过系统包管理器安装二进制，而是使用仓库内 `qemu/` submodule 从源码构建。

下面仍保留 Debian/Ubuntu 的手动安装示例（这些是构建依赖，不包含 QEMU 二进制包）：

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential perl bc bison flex libelf-dev libssl-dev file binutils \
  cpio gzip busybox python3 python3-venv ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev
```

如果你在 x86_64 主机上编译 `arm/arm64/riscv`，还需要交叉工具链，例如：

```bash
sudo apt-get install -y gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu
```

若要从源码交叉编译 `busybox`（推荐用于跨架构 initramfs），通常还需要对应的交叉 libc 头文件/开发包。
以 Debian/Ubuntu 为例可补充：

```bash
sudo apt-get install -y libc6-dev-armhf-cross libc6-dev-arm64-cross libc6-dev-riscv64-cross
```

`initramfs` 里的 `busybox` 也必须和目标架构一致，否则会在启动时出现
`Starting init ... error -8`（`Exec format error`）。
跨架构建议使用对应架构的**静态链接** busybox，并通过 `BUSYBOX_BIN` 指定路径。

## 2. 一键编译并启动

在仓库根目录执行：

```bash
git submodule update --init --recursive --depth 1 linux busybox qemu
./scripts/build-and-run-qemu.sh
```

或使用 `Makefile` 快捷目标（`make` 默认 x86）：

```bash
make
make riscv
make busybox ARCH=riscv
```

成功后会在 QEMU 串口里看到：

- `== custom kernel booted ==`
- 一个交互控制台 shell（不同架构会自动选择 `ttyS0` 或 `ttyAMA0`）

退出方式：

```sh
reboot -f
```

## 3. 分步执行（可选）

```bash
./scripts/build-kernel.sh
./scripts/build-busybox.sh
./scripts/build-qemu.sh
./scripts/build-initramfs.sh
./scripts/run-qemu.sh
```

指定架构示例：

```bash
# x86_64
ARCH=x86_64 ./scripts/build-and-run-qemu.sh

# arm64
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./scripts/build-and-run-qemu.sh

# arm
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- ./scripts/build-and-run-qemu.sh

# riscv (riscv64)
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-and-run-qemu.sh

# 只编译目标架构 static busybox（输出到 out/busybox/$ARCH/busybox）
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- ./scripts/build-busybox.sh

# riscv + 指定目标架构 busybox（示例路径）
ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- \
  BUSYBOX_BIN=/path/to/riscv64/busybox \
  ./scripts/build-and-run-qemu.sh

# 使用 Makefile 单独构建 busybox（默认最小 initramfs 配置）
make busybox ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-
```

## 4. 常用自定义参数

```bash
# 只改并行编译线程
JOBS=16 ./scripts/build-kernel.sh

# 启动更多内存和 CPU
MEMORY=4096 SMP=4 ./scripts/run-qemu.sh

# 传额外 QEMU 参数（例如启用 gdb stub）
./scripts/run-qemu.sh -s -S

# 调整内核日志级别（默认已是 loglevel=7，会打印较完整启动日志）
KERNEL_CMDLINE="loglevel=7 printk.time=1 panic=-1 console=ttyAMA0 rdinit=/init" \
  ./scripts/run-qemu.sh
```

## 5. 输出文件位置

- 内核镜像：`out/$ARCH/arch/...`（会随架构变化，默认 `ARCH=x86_64`）
- initramfs：`out/initramfs/$ARCH/initramfs.cpio.gz`
