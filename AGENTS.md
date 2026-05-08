# AGENTS.md instructions for D:\project\flutter\gm_hub

## 项目规则
1. 当前项目是 Flutter Windows 桌面应用。
2. 默认不编写测试代码，也不创建 `test` 目录。
3. 默认不主动执行测试命令，例如 `flutter test`。
4. 默认不主动执行静态分析，例如 `flutter analyze`、`dart analyze`；仅在用户明确要求时执行。
5. 涉及源码读取时，先按 BOM 判断编码，再显式解码；新增和修改文件统一使用 UTF-8，优先 UTF-8 without BOM。
