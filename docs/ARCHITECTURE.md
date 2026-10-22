# LifePilot Week 1 架构决策

## 客户端层
- UI: Flutter Material 3 (Chinese-first)
- Navigation: go_router `StatefulShellRoute.indexedStack`
- DI & reactive state: Riverpod Provider/StreamProvider
- Persistence: SQLite via Drift, generated code from drift_dev/build_runner

## 本地数据结构
- accounts: 账户
- categories: 收入 / 支出分类
- ledger_transactions: 账目，最小货币单位金额（第 1 周 UI 仅人民币）
- tasks: 待办，日期层面的 due_date，不冒充精确到时的提醒
- events: 事件表，日历 UI 后续实现
- journal_entries: 每日记录
- reminders: 预留，后续接调度器
- app_settings: 预留设置

## 数据流

User UI -> Repository -> Drift/SQLite -> StreamProvider -> UI

future AI -> candidate draft -> review -> same Repository (not bypass save)

## 未来多端同步注意
- all business objects use UUID
- created_at / updated_at dates persisted
- ledger soft deletion (`deleted_at`) to help sync later
- schema version and explicit migration policy
- future sync still needs conflict resolution and more complete tombstones, not done yet

## 非目标（第 1 周）
- No online accounts/login
- No network requests or AI providers
- No notifications scheduled
- No full backup solution
- No complete multi-currency transfers/refunds
- No iOS platform compilation within this deliverable environment
