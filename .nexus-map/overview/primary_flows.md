# 主链路

> rebuilt_at: 2026-05-08

## 1. 启动分流
1. `lib/main.dart:9-52` 解析命令行参数。
2. 包含 `multi_window` 或 `output` 时启动 `OutputWindowApp`。
3. 否则启动 `GmHubApp`，并把项目文件路径通过 `--project=` 或首个非 flag 参数传入主窗口。

## 2. 主窗口编辑链路
1. `lib/src/app.dart:20-39` 创建 `GetMaterialApp`。
2. `lib/src/router/app_pages.dart:12-24` 绑定 `ProjectController`。
3. `lib/src/ui/main_shell.dart:32-67` 构建主窗口骨架。
4. `lib/src/ui/facade/project_ui_facade.dart` 将 `ProjectStore` 分发给舞台、图层树、音频、骰子四个 facade。

## 3. 输出同步链路
1. `lib/src/controller/project_controller.dart:33-34` 监听 `ProjectStore`。
2. `lib/src/controller/project_controller.dart:148-178` 合并状态变化并串行刷新输出同步。
3. `lib/src/controller/project_controller.dart:227-252` 构建 `SyncRenderPayload` 并调用 `DesktopMultiWindow.invokeMethod(..., 'sync_render', payload)`。
4. `lib/src/output_window_app.dart:43-64` 接收并解析 payload。
5. `lib/src/output/output_sync_parser.dart:4-27` 将 payload 写入 `OutputSyncState`。

## 4. 保存与打开链路
1. `lib/src/ui/main_shell/main_shell_actions.dart:11-37` 提供菜单入口。
2. `lib/src/controller/project_controller.dart:88-127` 将打开、新建、保存、另存为、清空转发给 `ProjectStore`。
3. `lib/src/store/project_store_project_ops.dart:61-183` 处理项目创建、打开与另存为。
4. `lib/src/store/project_store_runtime_ops.dart:295-300` 走 `_saveNow()`。
5. `lib/src/store/project_file_service.dart:16-114` 负责 `.gmh/.json` 的具体读写。

## 5. Windows 打包与文件关联链路
1. `pubspec.yaml:28-49` 声明 `inno_bundle` 与安装器配置。
2. `build_exe.bat:23-120` 和 `scripts/build_exe.ps1:79-141` 调起 `inno_bundle`，再用 Inno Setup 生成安装器。
3. `windows/runner/main.cpp:38-85` 在非安装态下注册 `.gmh` 打开命令。
