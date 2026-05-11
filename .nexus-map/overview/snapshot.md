# 项目快照

> rebuilt_at: 2026-05-08

## 当前项目是什么
- GM Hub 是面向 TRPG 主持人的 Windows 桌面主控台。
- 主窗口负责编辑舞台、图层、音频与骰子；输出窗口负责玩家可见画面。
- 技术栈以 Flutter Windows 为主，窗口通信依赖 `desktop_multi_window`，主窗口框架使用 GetX。

## 当前主链路
1. `lib/main.dart` 解析启动参数，分流到主窗口或输出窗口。
2. 主窗口通过 `AppPages` 绑定 `ProjectController`，由控制器持有 `ProjectStore`。
3. `MainShell` 通过 UI facade 与 `ProjectStore` 交互。
4. `ProjectController` 在状态变化时构建 `SyncRenderPayload`，向输出窗口发送 `sync_render`。
5. `OutputWindowApp` 解析 payload，更新 `OutputSyncState` 并渲染玩家视图。
6. `ProjectFileService` 负责 `.gmh/.json` 项目文件的加载与保存。

## 当前真实状态
- 保存策略：手动触发 `保存`、`另存为项目`、`Ctrl+S`。
- 项目文件：默认 `.gmh`，兼容 `.json`。
- 安装打包：`inno_bundle` + Inno Setup EXE。
- 文件关联：安装态依赖安装器写注册表；非安装态由 `windows/runner/main.cpp` 运行时写入 `HKCU\Software\Classes`。
- git：当前仓库存在 `.git`，但历史只有 1 个提交，因此只能提供最基础的版本状态，不足以得出真实热点。

## 本图谱的证据边界
- 本次图谱不再引用旧的 AST 生成结果。
- 所有结论只基于当前仓库里的源码、脚本、README 和 git 元数据。
- 无法证明的内容会集中写在 `../risks/evidence_gaps.md`。
