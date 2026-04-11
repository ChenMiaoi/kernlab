# my_linux 目录职责

这个仓库的主要边界在仓库根目录一级。对于 `linux/`、`busybox/`、`qemu/` 这类上游 submodule，本 skill 默认把它们各自视为一个完整责任单元，而不是继续细拆其内部所有子目录。

## 顶层目录

| 路径 | 职责范围 | 改动建议 |
| --- | --- | --- |
| `.github/workflows/` | GitHub Actions 触发器、作业编排、CI 入口配置。当前主要入口是 [`ci.yml`](../../../.github/workflows/ci.yml)。 | 只放 CI 编排和触发条件；具体执行逻辑尽量留在 `ci/`。 |
| `busybox/` | BusyBox 上游源码 submodule。 | 仅在任务明确要求修改 BusyBox 源码，或更新 submodule 指针时改动。 |
| `ci/` | 仓库自有 CI 脚本与复用函数，例如依赖安装、构建检查、QEMU smoke test。 | 任何 CI 行为变化优先落在这里；保持无交互、可复现。 |
| `docs/` | 仓库的中文说明文档。当前重点文档是 [`qemu_kernel_run_zh.md`](../../../docs/qemu_kernel_run_zh.md)。 | 适合落用户指南、故障排查、使用说明。 |
| `linux/` | Linux 上游源码 submodule。 | 仅在任务明确要求修改内核源码，或更新 submodule 指针时改动。 |
| `out/` | 构建输出目录。存放内核、BusyBox、QEMU、initramfs 产物。 | 不手改、不提交；必要时只清理或重新生成。 |
| `qemu/` | QEMU 上游源码 submodule。 | 仅在任务明确要求修改 QEMU 源码，或更新 submodule 指针时改动。 |
| `research/` | 研究资料、学习计划、实验记录。 | 与实现逻辑分离；只有研究任务才改这里。 |
| `scripts/` | 构建、依赖检查、打包、启动的主脚本目录。 | 大多数行为改动应优先落在这里。 |

## 一方维护目录的细分

### `.github/workflows/`

- `ci.yml`: GitHub Actions 的主 CI 工作流，负责 checkout、安装依赖并调用 `make -C ci ci ...`。

### `ci/`

- `Makefile`: CI 侧的入口目标。
- `install-deps-ubuntu.sh`: Ubuntu CI 依赖安装。
- `lib.sh`: CI 公共函数。
- `run.sh`: 构建与 smoke test 串联入口。
- `check-artifacts.sh`: 校验构建产物是否齐全。
- `qemu-smoke.sh`: QEMU 启动冒烟验证。

### `docs/`

- `qemu_kernel_run_zh.md`: 面向使用者的中文运行说明。

### `research/`

- `research/mm/`: 当前存放内存管理学习计划与 LaTeX/PDF 资料。

### `scripts/`

- `build-kernel.sh`: 构建内核。
- `build-busybox.sh`: 构建 BusyBox。
- `build-qemu.sh`: 从 `qemu/` submodule 构建 QEMU。
- `build-initramfs.sh`: 生成 initramfs。
- `run-qemu.sh`: 启动 QEMU。
- `build-and-run-qemu.sh`: 串联构建与启动。
- `ensure-build-deps.py`: 依赖检查与自动安装。

### `out/`

- `out/$ARCH/`: 内核构建输出。
- `out/busybox/$ARCH/`: BusyBox 输出。
- `out/initramfs/$ARCH/`: initramfs 工作目录与压缩产物。
- `out/qemu/$ARCH/`: QEMU 构建输出。

## 重要根文件

| 路径 | 职责范围 | 改动建议 |
| --- | --- | --- |
| `Makefile` | 仓库根入口，负责统一常用目标和变量接口。 | 目标、参数入口变化时改；避免把复杂实现塞进 Makefile。 |
| `.gitmodules` | submodule 的路径、远端和 shallow 配置。 | 只有在明确变更 submodule 来源或拉取策略时修改。 |
| `.gitignore` | 忽略规则。 | 新增产物或本地缓存时再补充。 |
| `.codex` | 当前为保留的空文件。 | 未明确要求前不要 repurpose 或删除。 |

## 目录落点判断

- 改构建流程、参数传递、依赖检测：优先看 `scripts/`，必要时联动 `Makefile`。
- 改 GitHub Actions 触发方式或 CI 作业编排：优先看 `.github/workflows/`，配套逻辑放 `ci/`。
- 改用户说明、命令示例、排障文案：看 `docs/` 和 `README.md`。
- 改上游源码本体：仅在任务明确指定时进入 `linux/`、`busybox/`、`qemu/`。
- 改输出文件：通常不是代码改动，应通过重新构建生成，不直接编辑 `out/`。
