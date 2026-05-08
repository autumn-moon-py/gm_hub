# System Boundaries

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: C/C++ boundaries are AST-backed; Dart boundaries are inferred from module-level AST + manual inspection.

## 1) Bootstrap & Routing
- implementation_status: implemented
- code_path:
  - `lib/main.dart`
  - `lib/src/app.dart`
  - `lib/src/router/app_pages.dart`
- responsibility:
  - 启动参数分流主窗口/输出窗口。
  - 初始化 GetX 路由与 `ProjectController` 绑定。

## 2) Editor State Core
- implementation_status: implemented
- code_path:
  - `lib/src/store/project_store.dart`
  - `lib/src/store/project_store_project_ops.dart`
  - `lib/src/store/project_store_node_ops.dart`
  - `lib/src/store/project_store_runtime_ops.dart`
  - `lib/src/store/project_store_tree_ops.dart`
  - `lib/src/store/project_store_geometry_ops.dart`
- responsibility:
  - 管理画布、图层树、选择集、音频状态、流消息状态。
  - 负责手动保存、另存为、清空等核心项目生命周期操作。

## 3) Project Persistence Service
- implementation_status: implemented
- code_path:
  - `lib/src/store/project_file_service.dart`
- responsibility:
  - 读写 `.gmh`（gzip）与 `.json` 项目文件。
  - 执行资源路径导入与保存目标目录准备。

## 4) Main Editor UI
- implementation_status: implemented
- code_path:
  - `lib/src/ui/main_shell.dart`
  - `lib/src/ui/main_shell/main_shell_actions.dart`
  - `lib/src/ui/widgets/stage_canvas.dart`
  - `lib/src/ui/widgets/layer_tree_panel.dart`
  - `lib/src/ui/widgets/layer_tree/**`
  - `lib/src/ui/widgets/dice_panel.dart`
  - `lib/src/ui/widgets/bgm_panel.dart`
  - `lib/src/ui/widgets/flow_message_panel.dart`
- responsibility:
  - 承载主持端交互（菜单、快捷键、图层树、舞台编辑、骰子与音频）。
  - 对图层交互策略做最终 UI 约束（如双击选中、拖拽排序）。

## 5) Output Sync & Player View
- implementation_status: implemented
- code_path:
  - `lib/src/controller/project_controller.dart`
  - `lib/src/output_window_app.dart`
  - `lib/src/output/**`
- responsibility:
  - 维护输出窗口生命周期与心跳同步。
  - 消费 `sync_render` 合同并渲染玩家视图。

## 6) Domain Models
- implementation_status: implemented
- code_path:
  - `lib/src/model/project_model.dart`
  - `lib/src/model/render_item.dart`
- responsibility:
  - 定义项目聚合、节点类型、音频状态和渲染对象。

## 7) Windows Host & Packaging
- implementation_status: implemented
- code_path:
  - `windows/runner/main.cpp`
  - `windows/runner/**`
  - `pubspec.yaml` (`msix_config`)
  - `scripts/build_msix.ps1`
- responsibility:
  - 承载 Windows 原生入口与非安装态文件关联回退逻辑。
  - 生成 MSIX 安装包并声明 `.gmh` 文件关联。

## Degradation Notes
- `raw/ast_nodes.json.stats.module_only_file_counts.dart=42`，Dart 未获得结构级 query 解析。
- `.git` 缺失，无法提供提交热点与耦合对。
