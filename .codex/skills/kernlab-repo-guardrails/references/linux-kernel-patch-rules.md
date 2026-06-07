# Linux 内核 patch 代码与提交规则

这些规则用于指导 agent 在 `linux/` 内编写、修改和提交 Linux 内核代码。来源以仓库内 Linux 文档为准，尤其是：

- `linux/Documentation/process/coding-style.rst`
- `linux/Documentation/process/submitting-patches.rst`
- `linux/Documentation/process/submit-checklist.rst`
- 相关子系统的 `MAINTAINERS`、`Documentation/process/maintainer-handbooks.rst`、子目录文档

## 先确认维护边界

1. 先定位改动所属子系统，读相关 `MAINTAINERS` 条目、目录内文档和邻近代码。
2. 默认基于目标子系统 maintainer tree，而不是随意基于旧分支；`MAINTAINERS` 的 `T:` 条目优先。
3. 每个 patch 只解决一个逻辑问题；重构、移动代码、行为变化、修 bug、性能优化必须拆开。
4. 一个 patch 系列中每个 patch 都应能独立构建，不能让 `git bisect` 落到坏状态。

## C 代码风格

- 缩进只用 tab，tab 宽度 8；不要用空格缩进，不留行尾空白。
- 优先 80 列以内；超过 80 列只有在显著提升可读性且不隐藏信息时才接受。
- 不要拆分用户可见字符串，包括 `printk()`/日志字符串，保持可 grep。
- 函数左大括号另起一行；`if`/`switch`/`for`/`while`/`do` 的左大括号放同一行。
- `switch` 与 `case` 同列；`case` 下的语句再缩进一级。
- 不把多个语句或多个赋值塞进一行；避免逗号表达式和聪明但难审的表达式。
- 单语句分支通常不加大括号；但如果一个分支需要大括号，另一分支也加，保持对称。
- 函数应短而清楚。嵌套超过三层通常说明需要提前返回、拆辅助函数或重构控制流。
- 局部变量按生命周期和用途就近声明；不要提前声明一屏无关变量。
- 错误路径使用内核惯例：清晰的 `goto` unwind 标签，标签命名体现释放阶段，避免重复释放逻辑。

## 内核 API 与可维护性

- 使用某个设施就显式 `#include` 定义/声明它的头文件，不依赖间接 include。
- 新增用户可见 ABI、`/proc`、sysfs、ioctl、boot/module 参数时，必须同步更新对应文档。
- 全局 API 使用 kernel-doc；静态函数只有在确实提升维护性时才写 kernel-doc。
- 新 Kconfig 选项默认关闭，除非满足 Kconfig 文档中的例外；必须有 help text，并检查相关组合。
- 内存屏障、RCU、锁顺序、引用计数、对象生命周期必须在代码或提交说明中解释约束，不能只写“fix race”。
- 不引入无依据的抽象层；优先复用邻近子系统惯例、helper、命名和错误码。
- 性能优化必须给数字：测试环境、配置、基线、变化量和代价都写清楚。

## 提交说明写法

- 主题使用内核风格：`subsys: area: imperative summary`，祈使语气，不写“this patch”。
- 正文第一段说明问题，不是先描述实现。说明用户可见影响：崩溃、锁死、数据损坏、性能退化、误报等。
- 第二段开始说明技术方案和为什么这样改；必要时写清楚取舍和风险。
- patch/series 描述必须自包含；不要要求 maintainer 追溯旧版本、外部 issue 或聊天记录才能理解。
- 引用历史提交时使用至少 12 位 SHA-1 和原始 one-line summary：`Fixes: 54a4f0239f2e ("...")`。
- 有公开报告用 `Closes:`；背景讨论用 `Link:`，优先 lore.kernel.org，并在正文中概括关键点。
- 所有作者提交必须有真实身份 `Signed-off-by:`；使用 `git commit -s`。
- `Co-developed-by:` 后必须紧跟该共同作者的 `Signed-off-by:`。
- 只有确实收到且仍适用时才保留 `Reviewed-by:`、`Tested-by:`、`Acked-by:`；大改后移除并在 changelog 说明。

## 发送前检查

- 跑 `scripts/checkpatch.pl`，剩余告警必须能解释；checkpatch 是下限，不替代人工判断。
- 构建受影响配置：相关 `CONFIG=y/m/n`、`O=builddir`、必要时 `allnoconfig`/`allmodconfig`。
- 对新代码考虑 `make KCFLAGS=-W`、`sparse`、`make checkstack`。
- 覆盖关键运行时路径：错误路径、并发路径、引用计数、模块卸载、热插拔、32/64 位、大小端相关假设。
- 涉及锁、RCU、内存分配时，尽量用 lockdep、KASAN/KCSAN/KMSAN、fault injection 或子系统已有测试验证。
- 如果改变文档，确保相关 Documentation 构建不引入新警告。
