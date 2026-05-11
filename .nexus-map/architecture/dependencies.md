# 依赖关系

> rebuilt_at: 2026-05-08
> note: 基于当前源码导入关系与人工核对，不声称 AST 级完整图

## 运行时依赖图

```mermaid
flowchart TD
  A[lib/main.dart] --> B[GmHubApp]
  A --> C[OutputWindowApp]
  B --> D[AppPages / GetX Binding]
  D --> E[ProjectController]
  E --> F[ProjectStore]
  G[MainShell + UI Facades] --> E
  G --> F
  F --> H[ProjectModel + RenderItem]
  F --> I[ProjectFileService]
  E --> J[SyncRenderPayload]
  J --> C
  C --> K[OutputSyncParser + OutputSyncState]
```

## 跨窗口交互图

```mermaid
sequenceDiagram
  participant UI as MainShell/UI
  participant Store as ProjectStore
  participant Ctrl as ProjectController
  participant Out as OutputWindowApp

  UI->>Store: 编辑 / 选择 / 保存 / 运行态操作
  Store-->>Ctrl: notifyListeners
  Ctrl->>Ctrl: _buildSyncPayload()
  Ctrl->>Out: sync_render(payload)
  Out->>Out: parseSyncRenderPayload()
  Out->>Ctrl: select_node(id)
  Ctrl->>Store: selectNode(id)
```

## Windows 打包依赖图

```mermaid
flowchart LR
  A[pubspec.yaml: inno_bundle] --> B[build_exe.bat / build_exe.ps1]
  B --> C[inno_bundle generate iss]
  C --> D[ISCC.exe]
  D --> E[EXE installer]
  E --> F[.gmh file association in installer]
  G[windows/runner/main.cpp] --> H[non-packaged fallback association]
```

## 承重路径
- 输出合同路径：`ProjectStore.buildRenderList` -> `SyncRenderPayload.fromStore` -> `ProjectController._syncOutputWindow` -> `OutputWindowApp._handleMethodCall`
- 选择回传路径：`OutputWindowApp._selectNode` -> `ProjectController._handleMethodCall` -> `ProjectStore.selectNode`
- 保存路径：`MainShellActions` -> `ProjectController.saveProject*` -> `ProjectStore._saveNow` -> `ProjectFileService.saveProject`
- 安装器路径：`build_exe.bat` / `scripts/build_exe.ps1` -> `inno_bundle` -> `ISCC.exe`
