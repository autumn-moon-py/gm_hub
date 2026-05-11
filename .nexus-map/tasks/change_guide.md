# 改动入口指南

> rebuilt_at: 2026-05-08

## 改启动参数、窗口分流、全局异常处理
先看：
- `lib/main.dart`
- `lib/src/app.dart`
- `lib/src/router/app_pages.dart`
- `lib/src/error/global_exception_handler.dart`

## 改输出合同、玩家端渲染、输出窗口回选
先看：
- `lib/src/controller/project_controller.dart`
- `lib/src/output/sync_render_payload.dart`
- `lib/src/output_window_app.dart`
- `lib/src/output/output_sync_parser.dart`
- `lib/src/output/output_sync_state.dart`

## 改保存/打开/另存为、项目文件结构
先看：
- `lib/src/store/project_store_project_ops.dart`
- `lib/src/store/project_store_runtime_ops.dart`
- `lib/src/store/project_file_service.dart`
- `lib/src/model/project_model.dart`

## 改图层树、选择、多选、编组、拖拽
先看：
- `lib/src/store/project_store_node_ops.dart`
- `lib/src/store/project_store_tree_ops.dart`
- `lib/src/store/project_store_geometry_ops.dart`
- `lib/src/ui/widgets/layer_tree_panel.dart`
- `lib/src/ui/widgets/layer_tree/**`
- `lib/src/ui/widgets/stage_canvas.dart`

## 改音频导入与播放控制
先看：
- `lib/src/store/project_store_runtime_delegate.dart`
- `lib/src/store/project_store_runtime_ops.dart`
- `lib/src/ui/widgets/bgm_panel.dart`
- `lib/src/ui/widgets/bgm/bgm_panel_actions.dart`

## 改骰子行为与流消息
先看：
- `lib/src/store/project_store_runtime_delegate.dart`
- `lib/src/store/project_store_runtime_ops.dart`
- `lib/src/ui/widgets/dice_panel.dart`
- `lib/src/ui/widgets/flow_message_panel.dart`

## 改 Windows 打包、文件关联、双击打开
先看：
- `pubspec.yaml`
- `build_exe.bat`
- `scripts/build_exe.ps1`
- `windows/runner/main.cpp`
- `README.md`

## 任何跨边界改动
- 先同步更新 `models/concept_model.json`。
- 如果改的是导航或证据层结构，也同步更新 `models/navigation_index.json`。
