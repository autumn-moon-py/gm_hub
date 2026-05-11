# 打包与文件关联证据

> rebuilt_at: 2026-05-08

## 证据 1：当前使用 `inno_bundle`
- `pubspec.yaml:28-33`：`dev_dependencies` 中声明了 `inno_bundle: ^0.11.1`
- `pubspec.yaml:42-49`：存在 `inno_bundle:` 配置块

## 证据 2：当前主打包脚本是 EXE 安装器链路
- `build_exe.bat:23-57`：调用 `flutter pub get` 与 `flutter pub run inno_bundle`
- `build_exe.bat:83-120`：补丁 Inno Setup 脚本，注入中文语言与文件关联配置
- `scripts/build_exe.ps1:79-141`：PowerShell 版本执行同一路径

## 证据 3：非安装态文件关联在 C++ 宿主里回退注册
- `windows/runner/main.cpp:14-16`：定义 `.gmh` 扩展名、ProgId 和类型名
- `windows/runner/main.cpp:38-61`：写入 `HKCU\Software\Classes`
- `windows/runner/main.cpp:64-85`：仅在非安装态执行回退注册

## 证据 4：README 已经同步到 EXE 安装器流程
- `README.md:59-79`：明确写明当前是 `inno_bundle` + Inno Setup EXE 安装器
