# LifePilot 第一周验收清单

状态说明：`已验证通过` 表示已有真实命令、自动化测试或设备操作证据；`尚未验证` 表示只有静态代码或部分自动化覆盖；`尚未实现` 表示当前阶段明确没有对应功能；`验证失败` 表示已执行但结果未通过。

## 基础工程
- [x] `flutter doctor` 主要检查项通过（Android SDK 可用，2026-10-22）
- [x] `flutter pub get` 成功（2026-10-22）
- [x] `dart run build_runner build --delete-conflicting-outputs` 成功（2026-10-22）
- [x] `flutter analyze` 无 error（2026-10-22）
- [x] `flutter test` 通过（6 项，2026-10-22）
- [x] 已验证通过 — Android 模拟器在线，Debug APK 已安装，LifePilot 进程和前台 Activity 正常（2026-10-23）
- [x] 已验证通过 — 首页、记账、计划、AI、我的五个入口通过 ADB 点击及 UI 层级标识验证（2026-10-23；非人工视觉验收）

## 本地数据功能
- [x] 已验证通过 — 数据库测试确认默认现金账户与收支分类只初始化一次；模拟器记账表单可读取默认分类
- [x] 已验证通过 — 模拟器新增 28.50 元餐饮支出后，流水和记账页月度支出同步更新
- [ ] 尚未验证 — 新增支出后首页本月支出的设备端同步尚未单独操作确认
- [x] 已验证通过 — 模拟器新增 100 元其他收入，记账页收入与结余正确
- [x] 已验证通过 — 模拟器软删除支出后，流水和统计同步刷新
- [ ] 尚未验证 — 待办新增、首页计数和完成切换已有数据库测试，但尚未完成模拟器表单操作
- [ ] 尚未验证 — 每日记录已有 Repository 和页面，尚未完成模拟器保存操作及专项测试
- [x] 已验证通过 — 100 元收入在强制停止并重新启动 App 后仍存在；另有文件数据库关闭重开测试
- [ ] 尚未验证 — 断网后的记账、待办和日记操作尚未在模拟器执行

## 设计边界
- [x] AI 页面明确标识尚未接入 API，不能虚构解析结果（2026-10-21 静态代码检查）
- [x] 日程页面明确标识暂未实现（2026-10-21 静态代码检查）
- [x] 本周未实现提醒通知；待办日期不能冒充已经安排提醒（2026-10-21 静态代码检查）
- [x] 不承诺本地数据可以自动备份；卸载前需要谨慎（2026-10-21 静态代码检查）

## 2026-10-21 首次运行检查记录

- 已确认源码目录包含 `pubspec.yaml`、`lib/main.dart`、`test/`、`AGENTS.md` 和 `README.md`；当前目录尚未初始化 Git。
- Flutter、Dart、Android SDK 命令均不可用，`flutter doctor -v`、依赖安装、Drift 代码生成、静态分析、测试和 Android 运行均尚未执行成功。
- `lib/core/database/app_database.g.dart` 与 `android/` 目录尚未生成，符合首次运行前的源码包状态。
- 已静态审阅 Riverpod、go_router 五分支导航、8 张 Drift 表、账目/待办/日记 Repository 和三份测试源码；这不替代实际编译、测试或设备验收。
- 数据库当前为 `schemaVersion = 1`。`onCreate` 会创建全部表，`onUpgrade` 会显式失败以防止静默破坏数据；下一次表结构变更必须同时实现 migration 和旧库升级测试。
- 账目输入通过 Repository 使用整数分并校验收入/支出分类匹配。数据库表本身尚未添加金额非负与交易类型枚举约束，应在未来迁移中审慎补充，不能通过清库处理。

## 2026-10-22 构建与运行记录

- Flutter 3.47.7、Dart 3.13.5、Android SDK 36.1.0 和 Android Studio JDK 17 已由 `flutter doctor -v` 实际确认；Android 许可证已接受。
- `flutter pub get` 成功；Drift 代码生成成功且没有产生额外输出；`flutter analyze` 无问题；`flutter test` 的 6 项测试全部通过。
- 修复了四处 Drift `orderBy()` 调用：当前 API 要求每个排序子句传入单独的回调。修复后账目、分类、待办和日记排序查询均通过静态分析与数据库测试。
- Widget 测试会在卸载 ProviderScope 后推进 1ms 的 FakeAsync 时间，以完成 Drift 流清理，避免测试结束时遗留零延时计时器。
- 已启动 Android 模拟器，实际设备 ID 为 `emulator-5554`（系统报告为 Pixel Tablet）。`flutter run` 在 Gradle 配置阶段被 SDK 缺少 `ndkVersion = flutter.ndkVersion` 所需的 NDK `28.2.13676358` 阻塞，尚未安装或启动 App。
- Gradle 下载代理已按用户要求写入用户级 `C:\Users\daiwa\.gradle\gradle.properties`，仓库的 `android/gradle.properties` 未包含代理配置。新版 Android CLI 未提供所需 NDK 的下载 URL，需通过 Android Studio 的 SDK Manager 安装该精确版本后再继续设备验收。

## 2026-10-23 第一周收尾记录

- NDK 已可用；使用进程级 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 后，`flutter build apk --debug` 成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。该镜像设置未写入仓库。
- `flutter run -d emulator-5554 --debug --no-resident` 完成 APK 安装和 Flutter 引擎加载。最终一次运行的 Flutter CLI 因模拟器日志读取器停止返回退出码 1，但随后 ADB 独立确认进程 PID、前台 `MainActivity` 和首页 UI 均正常，因此“APK 构建成功”和“App 实际启动”分别有独立证据。
- ADB 自动点击并读取 UI 层级，确认首页、记账、计划、AI、我的五个页面都能切换。该结果属于设备自动化验收，不等同于人工视觉检查。
- 在模拟器上实际完成 28.50 元餐饮支出、100 元其他收入和支出软删除，记账页统计同步刷新；强制停止并重新启动后，保留的收入仍存在。
- 模拟器系统日期显示为 2026-10-22，与当前验收日期相差一天；涉及“今天”和月份边界的后续人工验收前应先同步模拟器时间。

## 后续迭代
- Week 2: 账目完整 CRUD、账户管理、分类、统计和预算
- Week 3: 待办完善、日历事件、每日记录编辑
- Week 4: 本地通知及提醒规则
- Week 5: FastAPI AI 解析、结构化草稿确认
- Week 6: 备份、综合测试和打包
