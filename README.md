# LifePilot — 项目说明与开发进度

**请务必打开这个包含 `pubspec.yaml` 的文件夹作为 Codex / VS Code 项目根目录。** 不要打开上一层空文件夹，也不要只打开 `docs/`。

当前仓库是实际 Flutter/Dart 源码，并非纯规划文档。2026-10-23 已在 Windows 环境完成 Flutter 分析、测试、Android Debug APK 构建、模拟器安装启动和五个主导航的自动化设备验收。当前仍是开发版本，不是已经发布的安装包。

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

## 三、当前开发进度

以下按当前代码与开发记录整理；`docs/` 中标明日期的旧记录反映当时状态，不代表当前仍未实现。

### 已实现

- 基础工程：Material 3、Riverpod、go_router、五个底部导航，以及本地 Drift/SQLite 数据库；当前 schemaVersion 为 2，已有 V1 → V2 迁移及迁移测试。
- **3.1 账户管理**：账户新增、编辑、停用与恢复、默认账户设置、基于初始余额及未删除收支计算余额，并与记账表单联动。用户反馈已通过模拟器人工验收。
- **3.2 分类管理**：收入和支出分类分开管理，支持新增、编辑名称与图标、排序、停用与恢复，并与记账表单联动。用户反馈已通过模拟器人工验收；`docs/WEEK3_DEVELOPMENT.md` 中待验收描述是当时的记录。
- 基础记账：人民币收入与支出的新增、编辑、软删除及即时撤销；按收支类型、分类和日期范围筛选；展示本月收支、结余及分类支出。停用账户或分类仍保留历史账目关联。
- 首页「本月支出」复用记账月度统计，按退款发生月份冲减支出；退款新增、删除和恢复会刷新金额。
- 计划与记录：待办新增、完成，以及日记新增、查看已有源码。

### 进行中：3.3 记账功能完善

已接入账目详情、商家录入、回收站恢复、账户/分类/日期和商家或备注关键词筛选、日期及金额排序，以及日/月/年收支、分类与账户统计和每日趋势柱状图。流水默认最多显示 50 条，可逐步加载更多；查询与筛选仍在内存中处理，尚需数据库分页及性能验收。

### 进行中：3.4 转账与退款

已接入人民币账户间转账、关联原支出的部分或全额退款，以及编辑、软删除和恢复入口；转账可从「记账」的「转账与退款」或「我的 → 账户管理 → 账户转账」进入。退款按退款日期冲减支出，转账不计入收支；余额和统计已联动。原支出存在有效退款时，删除及修改受到保护。相关服务和集成自动化测试已有覆盖，完整交互仍需模拟器验收。

### 已知问题与后续计划

- 流水仍会读取全部记录后在页面过滤，增量显示不等于数据库分页；大量数据下需要性能测试。月度统计在 Provider 创建时确定月份，应用持续跨月运行时可能不会自动切换统计周期。
- 转账和退款目前仅支持人民币，退款退回原账户；新表单、组合筛选、趋势图及跨模块操作仍需更多 Widget 和模拟器测试。
- AI 语义解析、真实通知调度、完整日历、备份和多端同步尚未实现。
- 后续优先完成 3.3/3.4 的设备验收、异常路径测试及数据库分页优化。

### 验证记录

`docs/WEEK3_DEVELOPMENT.md` 记录 2026-11-01 的代码生成、静态分析、29 项测试和 Android Debug APK 构建通过；这不是本次文档更新重新执行的结果。模拟器的设备端情况应与自动化测试分开看待，具体历史记录见 `docs/WEEK1_ACCEPTANCE.md` 和 `docs/WEEK3_DEVELOPMENT.md`。

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
