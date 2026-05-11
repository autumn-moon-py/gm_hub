# 证据层说明

> rebuilt_at: 2026-05-08

## 原则
- 证据层只收当前仓库里能直接验证的事实。
- 摘要层和架构层文档应当能回链到这里或 `raw/*.json`。
- `raw/*.json` 是机器可读材料，不写推断性结论。

## 当前 raw 文件
- `raw/workspace_tree.json`：工作区结构与关键计数。
- `raw/dart_files.json`：`lib/` 下 Dart 文件清单与分区。
- `raw/packaging_state.json`：当前打包与文件关联事实。
- `raw/test_state.json`：测试目录与测试能力现状。
- `raw/git_state.json`：git 基本状态与历史深度。
