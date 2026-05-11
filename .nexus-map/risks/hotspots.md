# 结构性热点

> rebuilt_at: 2026-05-08
> note: 当前只有 1 个 git 提交，以下不是历史热点，而是结构性热点

## 1. `lib/src/store/project_store.dart` + `project_store_*.dart`
- 原因：图层树、画布、选择、音频、骰子、保存、输出渲染派生都在这里汇合。
- 风险：接口或通知链轻微改动都可能波及主窗口、输出窗口和持久化行为。

## 2. `lib/src/controller/project_controller.dart`
- 原因：窗口生命周期、同步节流、输出回选都集中在控制器。
- 风险：同步去重、重试和窗口状态清理很容易产生时序回归。

## 3. `lib/src/output/sync_render_payload.dart`
- 原因：它既是发送端编码器，也是接收端解析契约的事实来源。
- 风险：字段调整会同时影响主窗口和输出窗口。

## 4. `windows/runner/main.cpp` + `build_exe.bat` + `scripts/build_exe.ps1`
- 原因：Windows 文件关联和安装器链路横跨 C++、批处理、PowerShell、Inno Setup。
- 风险：环境差异、路径处理和安装态/非安装态判断都容易出问题。

## 5. `lib/src/ui/facade/project_ui_facade.dart`
- 原因：它把一个大型 `ProjectStore` 拆给多个 UI 子域。
- 风险：若 facade 方法与 store 能力漂移，UI 表现会和底层真实状态不一致。
