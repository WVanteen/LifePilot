# LifePilot 第一周验收清单

## 基础工程
- [ ] `flutter doctor` 主要检查项通过（Android SDK 可用）
- [ ] `flutter pub get` 成功
- [ ] `dart run build_runner build --delete-conflicting-outputs` 成功
- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 通过
- [ ] Android 模拟器 / 真机可以启动
- [ ] 底部首页、记账、计划、AI、我的五个入口可切换

## 本地数据功能
- [ ] 首次启动自动生成默认现金账户与收支分类
- [ ] 在记账页面新增 28.50 元餐饮支出，流水中出现，首页本月支出增加 28.50 元
- [ ] 新增 100 元其他收入，收支结余正确
- [ ] 删除一笔账后列表和统计随之更新
- [ ] 新增待办，首页待办数量变化
- [ ] 点击待办前的复选框，完成数更新
- [ ] 写一条每日记录并能在日记页看到
- [ ] 关闭、重新打开 App 后，上述记录仍存在
- [ ] 断网后仍可以手动记账、添加待办与日记

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

## 后续迭代
- Week 2: 账目完整 CRUD、账户管理、分类、统计和预算
- Week 3: 待办完善、日历事件、每日记录编辑
- Week 4: 本地通知及提醒规则
- Week 5: FastAPI AI 解析、结构化草稿确认
- Week 6: 备份、综合测试和打包
