# Git Forensics

> generated_by: nexus-mapper v2 (local compatible run)
> verified_at: 2026-04-07
> provenance: `.nexus-map/raw/git_stats.json` + filesystem inspection

## Status
- hotspots skipped: no git metadata
- reason: workspace does not contain `.git`
- raw marker: `git_stats.json.note = "git analysis skipped: no .git metadata"`

## Non-git Risk Heuristics (Manual)
1. `lib/src/store/project_store*.dart`  
   状态、规则、IO、音频、骰子逻辑聚合，属于高耦合修改点。
2. `lib/src/controller/project_controller.dart`  
   输出窗口同步与生命周期控制集中，回归风险高。
3. `lib/src/ui/main_shell.dart` + `main_shell_actions.dart`  
   菜单/快捷键/保存链路入口，容易引入行为回归。
4. `windows/runner/main.cpp` + `pubspec.yaml(msix_config)`  
   关联安装分发与文件后缀绑定，环境差异风险高。

## What Cannot Be Proven in Current Workspace
- 无法计算 commit 热度（changes/risk）。
- 无法计算 co-change coupling pair。
- 无法给出作者分布与近期改动窗口。
