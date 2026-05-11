# 系统边界

> rebuilt_at: 2026-05-08

## 1. Bootstrap & Window Routing
- 代码位置：`lib/main.dart`
- 责任：识别主窗口/输出窗口启动参数，安装全局异常处理，决定启动哪个根应用。

## 2. Main App Shell
- 代码位置：`lib/src/app.dart`, `lib/src/router/app_pages.dart`, `lib/src/router/app_routes.dart`
- 责任：创建 GetX 应用壳，绑定 `ProjectController`，承接主窗口路由入口。

## 3. Main Editor UI
- 代码位置：`lib/src/ui/main_shell.dart`, `lib/src/ui/main_shell/**`, `lib/src/ui/widgets/**`, `lib/src/ui/facade/project_ui_facade.dart`
- 责任：组织舞台、图层树、音频、骰子和快捷键交互；将 UI 与 `ProjectStore` 解耦为 facade。

## 4. Editor State Core
- 代码位置：`lib/src/store/project_store.dart`, `lib/src/store/project_store_*.dart`, `lib/src/store/project_store_runtime_delegate.dart`
- 责任：维护项目聚合、图层树操作、选择状态、音频与骰子运行态、输出渲染列表及部分 UI 状态。

## 5. Project Persistence
- 代码位置：`lib/src/store/project_file_service.dart`
- 责任：加载和保存 `.gmh/.json` 项目文件，并负责导入资源路径的最小规范化。

## 6. Output Sync Runtime
- 代码位置：`lib/src/controller/project_controller.dart`, `lib/src/output/sync_render_payload.dart`
- 责任：维护输出窗口生命周期，监听 `ProjectStore`，构建并发送 `sync_render` 合同。

## 7. Output Render Client
- 代码位置：`lib/src/output_window_app.dart`, `lib/src/output/**`
- 责任：接收 `sync_render`，解析为 `OutputSyncState`，再执行玩家端布局与渲染。

## 8. Domain Models
- 代码位置：`lib/src/model/project_model.dart`, `lib/src/model/render_item.dart`
- 责任：定义项目文件聚合、节点类型、音频状态、UI 状态和输出渲染对象。

## 9. Windows Host & Distribution
- 代码位置：`windows/runner/main.cpp`, `windows/runner/**`, `pubspec.yaml`, `build_exe.bat`, `scripts/build_exe.ps1`
- 责任：承载 Windows 原生入口、非安装态文件关联回退，以及 EXE 安装器构建链路。
