# LifePilot — Codex 项目指令（AGENTS.md）

> 本文件在仓库根目录。Codex 每次修改前应先阅读本文件，再阅读 `README.md`、`docs/LifePilot_Product_and_Technical_Plan.md`、`docs/ARCHITECTURE.md` 和 `docs/WEEK1_ACCEPTANCE.md`。
>
> 当前任务：完成第一周 Flutter App 基础工程检查、修复和 Android 端运行验收。除非用户另有指示，不要提前实现 AI、多端同步或完整提醒系统。

## 1. 产品与技术基线

LifePilot 是个人使用的 Android / iOS 生活管理 App，融合记账、待办、日程、每日记录和 AI 提醒；同时支持手动表单及自然语言录入。

- 手机端：Flutter / Dart / Material 3。
- 状态管理：Riverpod；导航：go_router。
- 本地数据库：Drift + SQLite。
- 未来 AI 后端：FastAPI + Pydantic + 模型 API 适配层。
- 架构原则：**本地优先、离线可用、AI 只生成候选草稿、用户确认后保存**。
- 现阶段代码库的真实实现优先于规划文档。规划中提到的未来功能不代表已经完成。

## 2. 接手项目时必须先做

1. 确认当前工作目录含有 `pubspec.yaml` 和 `lib/main.dart`；否则不要继续执行 Flutter 命令，应先定位正确的项目根目录。
2. 执行 `git status --short`，如当前目录还不是 Git 仓库，应报告即可，不强行清理或重置。
3. 逐一阅读与本次任务相关的代码、文档与测试。
4. 检查 `flutter --version`、`dart --version`、`flutter doctor -v`；若未安装 Flutter，先明确告知缺失工具及安装建议，而不是反复运行注定失败的命令。
5. 简述任务拆解、计划变更的文件与可能风险，然后再动手。
6. 不要伪称已经构建、运行、截图或真机测试；所有验证状态必须与真实命令输出一致。

## 3. 目录与分层规范

遵循现有结构：

```text
lib/
├── app/                 # App 入口和路由
├── core/                # 数据库、通用 Provider、工具
├── features/
│   ├── home/
│   ├── ledger/
│   ├── planner/
│   ├── assistant/
│   └── settings/
├── shared/
└── main.dart
```

业务调用建议保持：`Page → Controller/Provider → Service/Repository → Drift/SQLite`。

- UI 不应直接拼接 SQL 或承担复杂财务计算。
- 手动录入与 AI 草稿确认必须使用统一业务保存入口。
- 本地 CRUD 不得依赖 AI API 网络连通。
- 异步页面处理 loading、empty、error；未实现功能须明确标注而非伪装可用。
- 先在现有代码上最小改动，不要为简单功能引入微服务或复杂层级。

## 4. 资金与日期的重要约束

- 财务金额使用整数最小货币单位（如 CNY 分），不得用 `double` 进行累计。
- 不能假定所有币种有两位小数。涉及币种精度需有明确规则。
- 交易类型区分 `expense`、`income`、`transfer`、`refund`，不得混淆。
- 转账只改变账户余额，不增加收入或支出；退款关联原交易并冲减对应支出。
- `created_at` 不等于实际消费时间；补记历史账目应归入实际消费日期。
- 日期与时间点必须区分；相对日期解析需要当前时间、时区和语言。
- AI 不得对缺少时间的信息凭空补出精确时刻。
- 统计金额和比率由程序计算，AI 只能根据真实数据解释。

## 5. AI 与数据安全

- 禁止在客户端写入模型 API Key、密码或其他秘密。API Key 放服务器环境配置中。
- AI 输出先经过结构校验与业务校验，生成可编辑草稿；第一版确认后才能落库。
- 模型不得自行编造分类/账户 ID；模糊交易性质应请求澄清。
- 不默认向模型上传全部账目、日记、联系方式等敏感上下文。
- AI 失败时允许重试或切换手动输入，不能丢掉用户填写的信息。
- 不允许 AI 直接修改或删除正式记录。

## 6. 数据库与迁移

- 使用稳定的业务主键，预留后续同步能力。
- 变更 Drift 表结构时，必须设计 schemaVersion 及 migration，覆盖原有记录。
- 禁止用卸载应用、删除数据库、删除测试等方式掩盖迁移问题。
- 同一草稿多次提交应通过稳定幂等 ID 防重复；相似金额本身不等于重复交易。
- 账户、金额、分类、事务回滚、时间处理等逻辑应有针对性测试。

## 7. 命令和平台说明

Windows 主开发环境优先验收 Android。Android/iOS 原生平台目录由 Flutter SDK 生成；当前源码包不包含 Flutter SDK、Android SDK 或 Xcode。

在确认 Flutter 可用、并且当前目录包含 `pubspec.yaml` 后，按顺序执行：

```powershell
flutter create --project-name lifepilot --platforms=android --org com.example .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter devices
flutter run
```

首次生成平台工程时不使用 `--overwrite`。不要覆盖 `lib/`、`pubspec.yaml`、`AGENTS.md` 等已存在文件。

在 Mac 上增加 iOS 平台工程、签名和测试；不得在 Windows 上声称已成功构建 iOS 安装包。

## 8. 禁止事项与审批规则

- 禁止 `git reset --hard`、`git clean -fd`、强制覆盖远端、擅自清空用户数据。
- 禁止随意改动未请求的模块或重写整个项目。
- 涉及大范围重构、迁移不兼容、删除文件、同步策略变更，应先解释原因与影响并征得用户确认。
- 不要因环境缺少依赖而“假设测试通过”。
- 完成后检查 `git diff`，防止临时文件、密钥或无关变更被保留。

## 9. 第一周验收优先级

1. 能打开真正的 Flutter 项目根目录。
2. `flutter pub get` 与 Drift 代码生成成功。
3. `flutter analyze`、`flutter test` 通过。
4. Android 模拟器或真机能运行。
5. 五个底部导航可以切换。
6. 可新增并查询本地账目、待办和每日记录；重启后持久化。
7. 首页数据与保存的账目和待办同步。
8. 如发现问题，优先定位并修复，暂不提前开发 Week 2–6 功能。

## 10. 每次完成任务时的报告格式

- 本次已完成：
- 修改的文件：
- 执行的命令与真实结果：
- 未执行/未验证的项目及原因：
- 已知风险：
- 下一步建议：
