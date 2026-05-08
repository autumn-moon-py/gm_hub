# 笔记区空白与图层撤回实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 缩小窗口时收紧笔记区右侧空白，并为图层域接入 `Ctrl+Z` 撤回。

**架构：** 在笔记编辑器中缩小按钮避让区域；在 `ProjectStore` 中加入图层历史快照栈，并在主窗口快捷键层接入撤回入口。撤回仅恢复图层树与选择状态，继续沿用现有的 store 通知与输出同步链路。

**技术栈：** Flutter, Dart, GetX, `ProjectStore`

---

### 任务 1：收紧笔记区按钮避让

**文件：**
- 修改：`lib/src/ui/widgets/right_sidebar_panel.dart`

- [ ] 缩小 `TextField` 右侧/底部预留，只保留按钮必要安全区。
- [ ] 保持全屏按钮不遮挡主要输入区域。

### 任务 2：实现图层快照撤回

**文件：**
- 修改：`lib/src/store/project_store.dart`
- 修改：`lib/src/store/project_store_runtime_ops.dart`
- 修改：`lib/src/store/project_store_project_ops.dart`
- 修改：`lib/src/store/project_store_node_ops.dart`
- 修改：`lib/src/store/project_store_tree_ops.dart`
- 修改：`lib/src/store/project_store_geometry_ops.dart`

- [ ] 增加图层历史快照结构与撤回栈。
- [ ] 在图层相关写操作前记录快照。
- [ ] 增加撤回方法并复用现有通知刷新链。

### 任务 3：接入 `Ctrl+Z`

**文件：**
- 修改：`lib/src/controller/project_controller.dart`
- 修改：`lib/src/ui/main_shell.dart`

- [ ] 暴露控制器撤回入口。
- [ ] 在主窗口快捷键中绑定 `Ctrl+Z`。

### 任务 4：格式化与验证

**文件：**
- 修改：本次涉及的 Dart 文件

- [ ] 运行 `dart format` 格式化本次修改文件。
- [ ] 复核关键代码片段，确认行为与设计一致。
