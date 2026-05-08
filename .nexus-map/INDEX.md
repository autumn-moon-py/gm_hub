# gm_hub INDEX

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: AST-backed for C/C++; Dart files are module-only AST coverage (no structural/import query), so `lib/**` dependency conclusions are inferred from file tree and manual inspection.

## Snapshot
- 项目是 Flutter Windows 双窗口主持工具：主窗口编辑，输出窗口展示。
- 核心状态中心仍是 `ProjectStore`（`project_store.dart` + 多个 `part` 扩展文件）。
- 当前保存策略已改为手动触发：`保存`、`另存为项目`、`Ctrl+S`。
- 已接入 `msix` 插件，可生成可安装包并关联 `.gmh` 后缀。
- 本仓库无 `.git` 元数据，hotspot/coupling 为降级结果（跳过）。

## 当前主链路
1. 启动分流：`lib/main.dart` 根据参数启动主窗口或输出窗口。  
2. 编辑态：`MainShell` -> `ProjectController` -> `ProjectStore`。  
3. 输出同步：`ProjectController` 周期性推送 `sync_render` 到 `OutputWindowApp`。  
4. 文件持久化：`ProjectFileService` 负责 `.gmh/.json` 读写。  
5. 安装分发：`pubspec.yaml(msix_config)` + `scripts/build_msix.ps1`。

## 最近有效变更（与旧图谱相比）
- 菜单改为左侧入口，新增保存/另存为/清空。
- 图层树改为双击选择，root 节点隐藏（逻辑保留）。
- 音频导入入口迁移到“背景音乐”区。
- 命运骰新增“加值输入”并区分主持端详细输出与玩家端简略输出。
- 新增 MSIX 安装包流水线与 `.gmh` 安装态文件关联。

## Evidence Gaps
- unknown: Dart 仅 module-level AST，无法从 AST 直接得到精确 import 边。
- evidence gap: `.git` 缺失，无法计算真实提交热点与耦合对。

## Navigation
- 系统边界: `./arch/systems.md`
- 依赖关系: `./arch/dependencies.md`
- 测试覆盖面: `./arch/test_coverage.md`
- 领域概念: `./concepts/domains.md`
- 机器可读模型: `./concepts/concept_model.json`
- Git 取证: `./hotspots/git_forensics.md`

## [操作指南] 强制执行步骤

> 本节是对所有读取本文件的 AI 发出的硬性操作指令，不是建议。

### 步骤1 — 必须先读完以下所有文件（顺序不限）

读完本文件后，在执行任何任务之前，必须依次 read 以下文件完整内容：

- `.nexus-map/arch/systems.md` — 系统边界与代码位置
- `.nexus-map/arch/dependencies.md` — 系统间依赖关系与 Mermaid 图
- `.nexus-map/arch/test_coverage.md` — 测试面与证据缺口
- `.nexus-map/hotspots/git_forensics.md` — Git 热点与耦合风险
- `.nexus-map/concepts/domains.md` — 核心领域概念

### 步骤2 — 按任务类型追加操作（步骤1 完成后执行）

- 若任务涉及接口修改、新增跨模块调用、删除/重命名公共函数：  
  先确认 `concept_model.json` 节点和边，再修改。
- 若任务涉及输出渲染合同（`sync_render`）：  
  必须联查 `project_store.dart`、`project_controller.dart`、`output_window_app.dart`。
- 若任务改变系统边界或分发方式（例如新增安装器、改启动路由）：  
  交付前更新 `.nexus-map`。
