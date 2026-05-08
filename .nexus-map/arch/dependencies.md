# System Dependencies

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: dependency graph for Dart is inferred (module-only AST); C/C++ host side is AST-backed.

## Runtime Dependency Map

```mermaid
flowchart TD
  A[lib/main.dart] --> B[GmHubApp / GetX Router]
  A --> C[OutputWindowApp]
  B --> D[ProjectController]
  D --> E[ProjectStore]
  F[MainShell + UI Widgets] --> D
  F --> E
  E --> G[ProjectModel + RenderItem]
  E --> H[ProjectFileService]
  D --> C
  C --> I[output/* parser + layout]
```

## Output Sync Sequence

```mermaid
sequenceDiagram
  participant UI as MainShell/UI
  participant Store as ProjectStore
  participant Ctrl as ProjectController
  participant Out as OutputWindowApp
  UI->>Store: 编辑操作/状态变更
  Store-->>Ctrl: notifyListeners
  Ctrl->>Ctrl: _buildSyncPayload()
  Ctrl->>Out: invokeMethod(sync_render, payload)
  Out->>Out: parseSyncRenderPayload + render
```

## Packaging Dependency (Installable Distribution)

```mermaid
flowchart LR
  A[pubspec.yaml: msix_config] --> B[dart run msix:create]
  C[scripts/build_msix.ps1] --> B
  B --> D[build/windows/installer/gm_hub_installer.msix]
  D --> E[AppxManifest.xml]
  E --> F[.gmh file association]
```

## Load-bearing Paths
- 输出合同路径：`ProjectStore.buildRenderList` -> `ProjectController._buildSyncPayload` -> `OutputWindowApp._handleMethodCall`
- 保存路径：`main_shell_actions` -> `ProjectController.saveProject*` -> `ProjectStore.saveProject*` -> `ProjectFileService.saveProject`
- 命运骰路径：`dice_panel` -> `DiceControlFacade.rollFateDice` -> `ProjectStore.rollFateDice` -> `pushFlowMessage(简略结果)`

## Risks / Constraints
- `ProjectStore` 仍是状态和行为耦合中心，接口变更影响面广。
- Dart import 边未由 AST 精确输出，跨模块依赖需要人工复核。
- `.git` 缺失，无法利用真实历史验证热点判断。
