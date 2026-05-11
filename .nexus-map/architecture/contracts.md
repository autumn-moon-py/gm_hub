# 跨边界合同

> rebuilt_at: 2026-05-08

## 1. `sync_render`
- 调用方向：主窗口 -> 输出窗口
- 发送方：`lib/src/controller/project_controller.dart:227-252`
- 编码位置：`lib/src/output/sync_render_payload.dart:27-132`
- 接收方：`lib/src/output_window_app.dart:43-64`
- 解析位置：`lib/src/output/output_sync_parser.dart:4-27`

### 字段
- `render`：渲染项数组，来自 `ProjectStore.buildRenderList()`。
- `flowMessages`：流消息数组，供输出窗口右下角显示。
- `canvas.width` / `canvas.height`：输出画布尺寸。
- `outputScaleMode`：当前输出缩放模式，代码里只接受 `stretch` 或 `contain`。

### 风险
- 发送端和接收端都依赖同一个 `SyncRenderPayload` 结构；字段漂移会直接影响玩家端渲染。
- `RenderItem` 同时承载几何、素材路径、文本样式和层级，属于高影响面合同。

## 2. `select_node`
- 调用方向：输出窗口 -> 主窗口
- 发送方：`lib/src/output_window_app.dart:132-140`
- 接收方：`lib/src/controller/project_controller.dart:36-64`

### 语义
- 输出窗口双击渲染对象后，会把 `{id: nodeId}` 发回主窗口。
- 主窗口只在消息来自当前输出窗口时接受该选择。

## 3. 项目文件合同
- 编码位置：`lib/src/model/project_model.dart:448-595`
- 读写位置：`lib/src/store/project_file_service.dart:16-114`

### 语义
- `.gmh` 是 gzip 压缩后的 JSON。
- `.json` 直接存储同一结构的可读 JSON。
- `uiState` 会随项目一起保存，因此输出缩放模式、折叠状态和笔记文本属于持久化内容。
