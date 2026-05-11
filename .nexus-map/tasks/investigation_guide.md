# 排障入口指南

> rebuilt_at: 2026-05-08

## 问题：启动后打开了错误窗口
先查：
- `lib/main.dart`
- `windows/runner/main.cpp`

## 问题：输出窗口打不开或不会刷新
先查：
- `lib/src/controller/project_controller.dart`
- `lib/src/output_window_app.dart`
- `lib/src/output/sync_render_payload.dart`

## 问题：输出窗口双击没有同步主窗口选择
先查：
- `lib/src/output_window_app.dart`
- `lib/src/controller/project_controller.dart`
- `lib/src/ui/widgets/stage/stage_hit_test.dart`

## 问题：保存失败、另存为异常、打开项目无效
先查：
- `lib/src/store/project_store_project_ops.dart`
- `lib/src/store/project_store_runtime_ops.dart`
- `lib/src/store/project_file_service.dart`
- `lib/src/model/project_model.dart`

## 问题：`.gmh` 双击不能打开项目
先查：
- `windows/runner/main.cpp`
- `build_exe.bat`
- `scripts/build_exe.ps1`
- `README.md`

## 问题：图片或音频丢失
先查：
- `lib/src/store/project_store_runtime_ops.dart`
- `lib/src/store/project_file_service.dart`
- `lib/src/store/project_store_runtime_delegate.dart`

## 问题：图层树行为和舞台行为不一致
先查：
- `lib/src/ui/facade/project_ui_facade.dart`
- `lib/src/store/project_store_node_ops.dart`
- `lib/src/store/project_store_geometry_ops.dart`
- `lib/src/ui/widgets/layer_tree_panel.dart`
- `lib/src/ui/main_shell/stage_content.dart`
