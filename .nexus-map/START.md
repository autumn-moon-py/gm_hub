# gm_hub START

> rebuilt_at: 2026-05-08
> purpose: fastest safe entry for AI agents

## 先记住这 6 件事
- 这是 Flutter Windows 双窗口应用：主窗口编辑，输出窗口展示。
- `lib/main.dart` 根据启动参数决定启动 `GmHubApp` 还是 `OutputWindowApp`。
- `ProjectController` 管输出子窗口生命周期，并把 `ProjectStore` 状态编码成 `sync_render` 发送出去。
- `ProjectStore` 是主状态中心，拆成多个 `part` 文件，涵盖图层树、画布、音频、骰子、保存与运行态 UI。
- 项目文件默认是 `.gmh`，底层由 `ProjectFileService` 读写，`.gmh` 实际是 gzip 压缩 JSON。
- Windows 打包现在走 `inno_bundle` + Inno Setup EXE；`windows/runner/main.cpp` 负责非安装态下的 `.gmh` 文件关联回退。

## 最短阅读路径
1. `overview/snapshot.md`
2. `architecture/systems.md`
3. `architecture/contracts.md`

## 按任务跳转
- 改输出合同：`architecture/contracts.md`
- 改保存/打开：`overview/primary_flows.md`
- 改安装器/双击打开：`architecture/windows_host_and_packaging.md`
- 判断风险和证据边界：`risks/evidence_gaps.md`

## 不要延续旧假设
- 当前仓库有 `.git`，但提交历史很浅。
- 当前项目没有活动中的 `msix` 配置，主打包链路是 EXE 安装器。
- 当前仓库没有自动化测试目录，因此不能把任何“已测试通过”写成事实。
