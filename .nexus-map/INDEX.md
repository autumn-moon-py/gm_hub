# gm_hub INDEX

> rebuilt_at: 2026-05-08
> provenance: current workspace inspection, targeted source reads, and local git metadata
> audience: AI-first, human-readable fallback

## Snapshot
- 项目是 Flutter Windows 双窗口主持工具：主窗口负责编辑与控制，输出窗口负责玩家视图。
- `ProjectStore` 仍是状态中心；`ProjectController` 负责窗口生命周期与 `sync_render` 同步。
- 项目文件格式以 `.gmh` 为主，兼容 `.json`；保存策略是显式触发而非自动落盘。
- 当前安装分发链路是 `inno_bundle` + Inno Setup EXE，不是 `msix`。
- 当前仓库存在 `.git`，但历史仅有 1 个提交，不足以支持真实热点/耦合分析。

## Read Order
1. `./START.md`：最快建立当前项目边界。
2. `./overview/snapshot.md`：确认项目快照。
3. `./architecture/systems.md`：确认系统边界与代码位置。
4. `./architecture/contracts.md`：涉及跨窗口合同或公共边界时必读。
5. `./tasks/change_guide.md`：准备改代码时使用。
6. `./risks/evidence_gaps.md`：需要判断证据可信度时使用。

## Directory Map
- `overview/`：一页式摘要与主链路。
- `architecture/`：系统边界、依赖关系、跨边界合同、Windows 宿主与打包。
- `domains/`：领域概念与术语。
- `tasks/`：改动入口与排障入口。
- `risks/`：结构性热点、证据缺口、回归关注点。
- `evidence/`：面向结论的证据摘要与机器可读 raw 数据。
- `models/`：机器可读概念图与导航索引。

## Task Routing
- 改启动参数、窗口分流、异常处理：先读 `architecture/systems.md` 和 `architecture/windows_host_and_packaging.md`。
- 改输出窗口同步、渲染合同、双击选中回传：先读 `architecture/contracts.md`。
- 改保存/打开/另存为、项目文件格式：先读 `overview/primary_flows.md` 和 `domains/concepts.md`。
- 改音频、骰子、图层树：先读 `domains/concepts.md` 与 `tasks/change_guide.md`。
- 改安装器、文件关联、构建脚本：先读 `architecture/windows_host_and_packaging.md` 与 `evidence/packaging_evidence.md`。

## Trust Model
- 高可信：源码直读能证明的行为、文件存在性、git 基本状态。
- 中可信：跨文件流程归纳、结构性热点判断。
- 低可信：真实提交热点、co-change 耦合、自动化测试结论；当前图谱不会伪造这些内容。
