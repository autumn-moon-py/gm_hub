# 领域概念

> rebuilt_at: 2026-05-08

## Project Aggregate
- `ProjectModel` 聚合了 `canvas`、`root node tree`、`audio tracks`、`audio state` 和 `uiState`。
- `ProjectModel.initial()` 会创建一个逻辑 root 节点，并预置 `CG`、`NPC`、`玩家`、`背景` 四个分组。

## Layer Tree Domain
- `NodeType` 只有 `group | image | text` 三种。
- root 节点是逻辑根，不在图层树 UI 中直接显示；图层树从 `project.root.children` 开始展示。
- 图层树支持多选、编组、解组、拖放排序；这些操作都回到 `ProjectStore` 完成。

## Render Domain
- `RenderItem` 是从节点树派生出的输出对象，承载世界坐标、缩放、旋转、透明度、文本和素材路径。
- 输出窗口不共享 `ProjectStore`，完全依赖 `sync_render` 负载。

## Audio Domain
- `AudioTrackModel` 描述曲目 `id/name/asset/tags`。
- `AudioStateModel` 描述当前曲目、循环、音量和播放状态。
- 音频资源导入目前只是路径规范化，不做复制入仓。

## Dice Domain
- 普通骰子和预设骰子都通过 `ProjectStore` 运行。
- 命运骰支持额外加值输入。
- 流消息会被输出窗口共享显示，因此主持端投骰结果可能同时影响玩家侧的简化展示。

## UI State Domain
- `UiStateModel` 持久化折叠分组、输出缩放模式、图层树/笔记折叠状态和笔记文本。
- 这意味着部分 UI 行为不是纯运行态，而是项目文件的一部分。

## Project Lifecycle Domain
- 生命周期动作包含：新建、打开、保存、另存为项目、清空。
- 保存是显式动作，当前没有自动保存链路。
