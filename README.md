# GM Hub

GM Hub 是一个面向 TRPG 主持人的 Windows 桌面主控台：  
主持端编辑场景并控制播放，玩家端通过独立输出窗口实时看到最终画面。

## 核心能力

- 双窗口架构  
  主窗口（主持编辑）+ 输出窗口（玩家展示），通过 `sync_render` 实时同步。

- 场景编辑  
  支持图片/文字/分组图层，支持拖拽排序、编组解组、变换、对齐分布等。

- 图层树交互（当前规则）
  - UI 不显示 root 节点（项目逻辑仍保留 root）。
  - 双击图层才选中；支持多选编组/解组入口。
  - 支持拖拽改顺序；右键菜单保留重命名、添加、删除等核心操作。

- 手动保存模型
  - 保存策略为“触发才落盘”，不做自动写盘。
  - 支持 `保存`、`另存为项目`、`清空`。
  - 快捷键：`Ctrl+S` 保存，`Del` 删除选中。

- 音频控制
  - 背景音乐区可直接导入 MP3。
  - 单播放器 + 播放列表切换，降低导入卡顿。

- 骰子系统
  - 常规表达式投骰（如 `2d6+1`）。
  - 命运骰（默认 4 颗，`+1/0/-1`）支持“加值输入”。
  - 玩家输出区只显示命运骰总结果；主持区显示详细计算与 CoC 判定。

- 项目文件
  - 默认扩展名：`.gmh`
  - 兼容 `.json` 读写

## 目录概览

- `lib/src/store/`：项目状态核心（`ProjectStore` 及各类 ops）
- `lib/src/ui/`：主窗口 UI、图层树、舞台、骰子、音频
- `lib/src/controller/`：主控逻辑与输出同步调度
- `lib/src/output*`：输出窗口渲染与同步解析
- `windows/runner/`：Windows 原生宿主入口
- `.nexus-map/`：项目结构知识库（供 AI/开发快速定位）

## 运行（Windows）

```bash
flutter pub get
flutter run -d windows
```

启动时直接打开项目文件：

```bash
flutter run -d windows -- --project=D:\path\to\your_project.gmh
```

## 打包安装包（EXE，默认中文 + `.gmh` 关联）

项目已切换为 `inno_bundle` + Inno Setup 的 EXE 安装包流程：

- 输出目录：`build/windows/x64/installer/Release`
- 输出文件名示例：`GMHub-x86_64-1.0.0+1-Installer.exe`
- 后缀关联：`.gmh`（安装后双击 `.gmh` 可拉起程序）
- 安装器默认语言：简体中文

### 一键打包（cmd）

```bash
.\build_exe.bat
```

### 环境要求

- 已安装 Inno Setup 6（需可找到 `ISCC.exe`）
- 若 Inno Setup 缺少简体中文语言文件，项目会优先使用：
  `scripts/Languages/ChineseSimplified.isl`

## 代码分析（Windows）

推荐：

```bash
flutter analyze --no-pub
```

说明：

- 优先使用 Flutter 内置 Dart 环境，避免系统 `dart` 版本不一致导致误报。
- 若分析长时间无输出，先检查残留 `flutter/dart` 进程后重试。
