# Test Coverage (Static)

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: repository tree inspection + manual code walk; tests were not executed.

## Current State
- 未发现 `test/`、`integration_test/` 等自动化测试目录。
- 当前覆盖面属于“纯人工回归 + 静态检查”状态。

## High-Risk Untested Areas
- `lib/src/store/project_store*.dart`  
  风险：图层树、保存、音频、骰子等多域行为集中在同一状态核心。
- `lib/src/controller/project_controller.dart`  
  风险：输出窗口同步、心跳检查、窗口生命周期。
- `lib/src/output_window_app.dart` 与 `lib/src/output/*`  
  风险：`sync_render` 合同解析与渲染行为漂移。
- `windows/runner/main.cpp` + `pubspec.yaml(msix_config)`  
  风险：文件关联在“安装态/非安装态”双路径的一致性。

## Minimum Regression Suite (Suggested)
1. `ProjectModel` 序列化回环：`.gmh` 与 `.json` 的读写一致性。
2. 图层树行为：双击选择、多选编组/解组、拖拽排序显示顺序。
3. 保存链路：`保存`、`另存为项目`、`Ctrl+S` 仅在触发时落盘。
4. 输出合同：主窗口 payload 与输出窗口解析字段一致。
5. 命运骰：加值计算、主持端详细输出、玩家端简略输出分流。
6. MSIX：安装后 `.gmh` 双击打开与参数注入是否正常。

## Evidence Gap
- unknown: 无自动化测试结果，以上仅为静态测试面建议。
