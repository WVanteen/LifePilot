# Codex 第一次接手 LifePilot 的任务

请先阅读项目根目录下的 `AGENTS.md` 和 `README.md`，以及 `docs/LifePilot_Product_and_Technical_Plan.md`、`docs/ARCHITECTURE.md` 和 `docs/WEEK1_ACCEPTANCE.md`。

当前目标：**完成第一周基础工程的实际验证与修复**，不要越级开发 AI 或多端同步。

请严格按以下顺序操作：

1. 输出当前工作目录，并确认该目录包含 `pubspec.yaml`、`lib/main.dart`、`test/`、`AGENTS.md` 和 `README.md`。如果文件缺失，先指出应该切换到哪个目录，禁止在错误目录执行 `flutter create`。
2. 读取现有工程与测试，检查 `git status --short`；如果还不是 Git 仓库，正常报告，不将此视为源码不存在。
3. 检查 Flutter/Dart SDK 是否可用。如果 `flutter` 不存在，请给出 Windows 11 上 Flutter + Android Studio 安装与 PATH 配置步骤，不要假装运行测试成功。
4. 若 SDK 可用，先用不覆盖项目源码的方式生成 Android 平台目录，再执行：`flutter pub get`、`dart run build_runner build --delete-conflicting-outputs`、`flutter analyze`、`flutter test`。
5. 对真实出现的报错逐项定位并做最小修复，保持现有数据模型和功能，不做无关重构。
6. 尝试 Android 模拟器/真机运行，检查五个导航和记账、待办、日记的本地持久化。
7. 根据真实检查结果更新 `docs/WEEK1_ACCEPTANCE.md`，最后汇总已完成、修改文件、成功/失败的命令、无法验证的原因和下一步建议。

限制：不要清空数据库、删除用户改动、运行破坏性 Git 命令、硬编码密钥或跳过测试。任何影响较大的重构和数据库迁移先征得用户确认。
