---
name: my-linux-repo-guardrails
description: Repo-specific guidance for working in the my_linux repository. Use when tasks need directory ownership or edit boundaries, commit strategy, Conventional Commit subjects, Signed-off-by enforcement, or focused Pull Request rules. Also covers Chinese requests about 目录职责、提交规范、PR 规则、atomic commits、refactor-then-feature, and large commit bodies.
---

# my_linux Repo Guardrails

在 `my_linux` 仓库内工作时使用这个 skill。

## 快速流程

1. 开始改动前，先读 [references/repo-layout.md](references/repo-layout.md)，确认这次任务应该落在哪个目录。
2. 优先改动一方维护的目录：`scripts/`、`ci/`、`docs/`、`.github/workflows/`、`research/`、`Makefile`。不要手改 `out/` 产物。
3. 把 `linux/`、`busybox/`、`qemu/` 视为上游 submodule：
   - 只有任务明确要求修改上游源码，或明确要求更新 submodule 指针时，才进入这些目录。
   - 单纯更新 submodule 指针时，优先单独成 commit。
4. 动手前先想清楚 commit 边界：
   - 一个 commit 只承载一个逻辑变化。
   - 若功能依赖重构，先做重构 commit，再做功能 commit。
5. 准备提交或给出提交命令时，一律使用 `git commit -s`。
6. 提交标题、body、PR 聚焦范围，按 [references/commit-and-pr-rules.md](references/commit-and-pr-rules.md) 执行。
7. 如果一个 commit 达到“大提交”阈值，必须写 body，并使用 `- ...` 分点说明主要改动。

## 仓库内的工作边界

- `Makefile` 是入口层，负责把公共参数透传给脚本。默认把构建细节放进 `scripts/`，只在入口、目标、参数接口变化时改 `Makefile`。
- `scripts/` 是构建、打包、启动、依赖检查的主实现层。大多数行为变更优先落在这里。
- `ci/` 是 CI 执行层。改 `.github/workflows/` 时，通常要同步检查 `ci/` 是否也需要配套调整。
- `docs/` 是面向人的说明文档。纯文档修订尽量不要和行为改动混在同一个 commit。
- `research/` 是研究资料和学习记录，不是运行时路径。除非任务明确涉及研究文档，否则不要把实现改动混进来。
- `out/` 是生成产物目录，不应手工编辑，也不应纳入提交。

## 提交与 PR 的强约束

- `atomic-commits`: 一个 commit 只做一个逻辑变化。
- `refactor-then-feature`: 重构先提交，功能后提交，两个逻辑不要揉在一起。
- `focused-prs`: 一个 PR 只聚焦一个主题。
- `signed-commits`: 作者自己产生的提交必须使用 `git commit -s`。
- `large-commit-body`: 简单提交可以只有标题；较大提交必须带 body，并用 `- ...` 分点说明。

## 实用检查

- 用 `git diff --cached --stat` 判断文件数和增删行数，估算 staged commit 是否已达到“大提交”阈值。
- 用 `git show --stat --format=fuller HEAD` 检查最近一次提交是否包含 `Signed-off-by:` trailer。
- 如果同一任务同时需要重构和功能，先提交重构，再继续后续功能或修复。

## 参考

- 目录职责与编辑落点：[references/repo-layout.md](references/repo-layout.md)
- 提交与 PR 规则：[references/commit-and-pr-rules.md](references/commit-and-pr-rules.md)
