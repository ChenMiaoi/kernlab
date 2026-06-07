# kernlab 提交与 PR 规则

以下规则在本仓库内按强约束处理。

## 必须遵守

- `atomic-commits`: 一个 commit 只包含一个逻辑变化。
- `refactor-then-feature`: 先重构，再功能；必须拆成独立 commit。
- `focused-prs`: 一个 PR 只聚焦一个主题。
- `signed-commits`: 仓库内提交必须使用 `git commit -s`，确保每个 commit 都带有有效的 `Signed-off-by:` trailer。
- `large-commit-body`: 简单提交可以只有标题行；改动量较大的提交必须带 body，并用分点条目说明主要改动。

## 提交信息策略

- 保留 Conventional Commit 前缀：`feat:`、`fix:`、`docs:`、`refactor:`、`test:`、`chore:`。
- 可选使用 scope，例如：`feat(ci): ...`、`fix(sync): ...`。
- 前缀后的主题句使用祈使语气，描述清晰。
- 主题行尽量不超过 72 个字符。
- 作者自己产生的 commit 一律使用 `git commit -s`。
- 简单提交可以只写标题行，不强制写 body。
- 改动量较大的提交必须写 body，并使用 `- ...` 这类分点条目说明做了什么。

## 大提交阈值

当前 hook 与 CI 将“较大提交”定义为满足以下任一条件的单个 commit：

- 改动至少 6 个文件。
- 新增与删除总行数至少 150 行。

自检时优先使用：

```bash
git diff --cached --stat
git diff --cached --shortstat
```

如果 staged 结果已经碰到上面的阈值，就不要只写标题行。

## PR 规则

- 一个 PR 只解决一个主题，方便 reviewer 一次看清楚目的、范围和验证方式。
- 如果功能依赖前置重构，默认做法是：
  - 先提交重构 commit。
  - 再提交功能 commit。
- 如果这个重构本身可独立评审、可被其他后续工作复用，优先拆成独立 PR。
- 如果重构只是当前主题内的小型铺垫，也可以与功能放在同一个 PR，但仍必须分成独立 commit。
- 不要把文档清理、CI 整理、submodule bump、功能变化混成“顺手一并提交”，除非它们都服务于同一个主题。

## 推荐命令

简单提交：

```bash
git commit -s -m "fix(initramfs): restore /init symlink"
```

较大提交：

```bash
git commit -s \
  -m "feat(qemu): build emulator from bundled submodule" \
  -m "- add repo-managed QEMU build path and output directory
- wire Makefile and scripts to reuse the built binary
- update docs and CI to validate the new workflow"
```

## 提交前检查清单

- 这次 staged 内容是否只表达一个逻辑变化？
- 是否把“重构”和“功能/修复”拆成了不同 commit？
- 提交命令是否使用了 `git commit -s`？
- 如果是较大提交，是否补了 body，并用 `- ...` 分点说明主要改动？
- 这个 PR 是否仍然只围绕一个主题？
