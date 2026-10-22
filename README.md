# LifePilot — 第一周 App 基础工程 + 全套规划文档

**请务必打开这个包含 `pubspec.yaml` 的文件夹作为 Codex / VS Code 项目根目录。** 不要打开上一层空文件夹，也不要只打开 `docs/`。

当前仓库是实际 Flutter/Dart 源码，并非纯规划文档；但**还未在本交付环境完成 Flutter 编译或真机验证**。这是供继续开发的 Week 1 骨架，而不是已经发布的安装包。

## 一、项目文件在哪里

```text
LifePilot/                  ← 打开这里（或解压目标文件夹本身）
├── AGENTS.md               ← Codex 开发规范（原 AGENT.md 已重命名）
├── README.md               ← 当前说明
├── pubspec.yaml            ← Flutter 项目根目录标志
├── lib/                    ← 真正的 Dart 源代码
├── test/                   ← 测试代码
├── docs/
│   ├── LifePilot_Product_and_Technical_Plan.md
│   ├── ARCHITECTURE.md
│   ├── WEEK1_ACCEPTANCE.md
│   └── CODEX_FIRST_RUN.md
├── backend/                ← 后续 AI 后端规划入口（暂未实现）
└── setup_windows.bat       ← Flutter 安装好之后的初始化脚本
```

**下载 ZIP 后应把它“解压到”一个新的项目文件夹**，例如 `D:\Projects\LifePilot`。因为本 ZIP 根层直接包含上述文件，不需要再从内部寻找第二层 `lifepilot` 目录。

## 二、首次启动（Windows / Android）

必须先安装 Flutter SDK、Android Studio / Android SDK，并配置 Flutter 到 PATH。推荐在 VS Code 安装 Dart 和 Flutter 扩展。

打开项目根目录的 PowerShell 终端：

```powershell
flutter --version
flutter doctor -v
flutter create --project-name lifepilot --platforms=android --org com.example .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter devices
flutter run
```

也可以运行 `setup_windows.bat` 执行初始化、依赖安装、代码生成与静态检查；它不会自动安装 Flutter SDK。

**禁止使用 `flutter create --overwrite`。** 生成平台目录时不要覆盖已有 `lib/`、`pubspec.yaml` 和配置文件。

iOS 平台目录以后在 macOS / Xcode 环境下生成和构建，例如在 Mac 上执行 `flutter create --platforms=ios .`。Windows 不能编译 iOS 应用。

## 三、当前实际实现范围

- Flutter Material 3、Riverpod、go_router 和五个底部导航：**已有源码**。
- Drift/SQLite 8 张表，首次运行默认账户与分类：**已有源码**。
- 基础收入/支出新增、删除、流水统计：**已有源码**。
- 待办新增、完成，日记新增与查看：**已有源码**。
- AI 语义解析、真实通知调度、完整日历与备份同步：**尚未实现**。
- Flutter 分析、单元测试、Android 设备运行：**需要在安装 SDK 的设备上验证**。

注意：这是开发版本，未完成稳定备份前不要保存不可丢失的财务信息。

## 四、推荐阅读顺序

1. `AGENTS.md`：Codex 修改代码的边界与验收规范。
2. `docs/LifePilot_Product_and_Technical_Plan.md`：完整产品需求、记账设计、数据库、AI、接口和路线图。
3. `docs/ARCHITECTURE.md`：当前代码架构。
4. `docs/WEEK1_ACCEPTANCE.md`：第一周逐项验收。
5. `docs/CODEX_FIRST_RUN.md`：可直接发给 Codex 的第一轮任务说明。

## 五、遇到“项目文件不存在”的处理

如果 Codex 报告缺失 `pubspec.yaml` / `README.md` / `lib/`，**先检查它打开的工作目录是否正确**。这份 ZIP 已包含这些文件；进入正确目录后，再执行 Flutter 命令。

如果命令提示找不到 `flutter` 或 `dart`，说明开发机没有正确安装或配置 Flutter SDK，和项目是否存在是两个独立问题。
