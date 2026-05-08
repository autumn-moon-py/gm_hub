# Domain Concepts

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: `project_model.dart`, `project_store*.dart`, `project_controller.dart`, `output_window_app.dart`; Dart relations are inferred.

## Project Aggregate
- `ProjectModel` 聚合了 `canvas / root node tree / audio tracks / audio state / ui state`。
- 当前产品语义是“主持编辑态 + 玩家展示态”双窗口协作。

## Layer Tree Domain
- `NodeType = group | image | text`。
- 关键规则：
  - root 逻辑节点保留，但 UI 可隐藏 root 展示。
  - 可见性/锁定可由节点独立控制，且存在祖先约束传播。
  - 排序影响渲染层级（上方项应显示在顶层）。

## Render Domain
- `RenderItem` 是输出视图的派生对象，包含世界坐标、缩放旋转、透明度、素材与文本字段。
- 输出端完全依赖 `sync_render` 负载，不直接访问主状态对象。

## Audio Domain
- `AudioTrackModel` + `AudioStateModel` 描述曲目、循环、音量、播放状态。
- 当前实现为单播放器 + 播放列表切换，降低导入音频时初始化卡顿。

## Save & Project Lifecycle Domain
- 保存策略：仅显式触发 `save / save as` 时写盘。
- 生命周期动作：`新建`、`打开`、`保存`、`另存为项目`、`清空`。

## Dice & Host-only Preview Domain
- 常规骰：表达式求值并推送结果到流消息。
- 命运骰：支持“加值输入”，同时输出：
  - 玩家区：简略总结果（`命运骰=总值`）
  - 主持区：明细（本次结果、公式、CoC判定、标记血量）

## Packaging Domain
- 使用 `msix` 生成可安装包。
- 通过 `msix_config.file_extension` 声明 `.gmh` 关联。
- 非安装态下由 `windows/runner/main.cpp` 回退注册文件关联（安装态不执行该回退）。

## Evidence Gap
- `raw/ast_nodes.json` 显示 Dart 为 module-only coverage，细粒度依赖关系未由 AST 直接给出。
