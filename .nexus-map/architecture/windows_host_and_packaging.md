# Windows 宿主与打包

> rebuilt_at: 2026-05-08

## 当前真实打包链路
- `pubspec.yaml:28-49` 使用 `inno_bundle`，并提供安装器基本信息。
- `build_exe.bat:23-120` 在 cmd 环境下执行 `flutter pub get`、调用 `inno_bundle`、补丁语言与文件关联设置，再交给 `ISCC.exe`。
- `scripts/build_exe.ps1:79-141` 在 PowerShell 环境下执行同样的链路。
- `README.md:59-79` 也已同步说明当前是 EXE 安装器流程。

## `.gmh` 文件关联
- `windows/runner/main.cpp:14-16` 定义扩展名和 ProgId。
- `windows/runner/main.cpp:38-61` 把 `.gmh`、默认图标和 `open` 命令写入 `HKCU\Software\Classes`。
- `windows/runner/main.cpp:64-85` 只有在 `IsRunningPackaged()` 为 false 时才执行运行时回退注册。

## 启动参数与文件打开
- `windows/runner/main.cpp:87-93` 把原生命令行参数传递给 Dart。
- `lib/main.dart:32-39` 把首个非 flag 参数或 `--project=` 视为启动项目路径。

## 与旧图谱相比的修正
- 当前仓库没有活动中的 `msix_config`。
- 当前构建脚本是 `build_exe.bat` / `scripts/build_exe.ps1`，不是 `build_msix.ps1`。
- 当前文件关联策略是“安装器负责安装态，`main.cpp` 负责非安装态回退”。
