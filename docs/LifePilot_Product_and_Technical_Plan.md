# LifePilot 产品规划与技术设计文档

> 文档版本：V1.0\
> 更新时间：2026-10-20\
> 项目阶段：MVP 规划 / 第一周基础工程\
> 产品平台：Android / iOS 独立 App\
> 当前策略：本地优先，预留多端同步能力

## 1. 项目概述

### 1.1 产品定位

LifePilot 是一款面向个人用户的 AI
生活管理助手，将记账、待办事项、日程事件、每日记录和智能提醒整合到一个手机
App
中。用户既可以使用传统表单录入，也可以用自然语言描述日常行为，由系统将信息整理成结构化数据，并在用户确认后保存。

产品不是把记账、日历和聊天机器人简单拼在一起，而是围绕"记录一次、合理关联、适时提醒、方便回顾"构建统一的个人生活数据系统。

### 1.2 目标用户与使用方式

-   首期用户：个人自用。
-   平台：Android / iOS 独立 App。
-   输入方式：手动表单 + 自然语言。
-   核心模块：记账、事项与日程、每日记录、AI
    提醒，三类核心能力均衡发展。
-   网络策略：基础记录、查询和已安排的本地提醒优先在设备上运行；AI
    能力需要网络和后端服务。
-   扩展方向：未来可以加入云端备份、多设备同步、语音录入、票据识别和外部日历集成。

### 1.3 产品目标

1.  将个人收支记录、待办、日程和生活日志放在同一个应用中。
2.  通过自然语言降低录入成本，支持一次输入提取多条结构化记录。
3.  通过本地通知和明确的提醒规则降低忘事概率。
4.  根据真实历史数据提供可解释的消费统计和生活回顾。
5.  在保护个人数据的前提下，为未来多端同步预留架构空间。

### 1.4 设计原则

-   **本地优先：** 账目、事项、日程、日记首先写入本地数据库。
-   **AI 辅助而非代替业务规则：** AI
    负责理解和生成候选数据；程序负责金额计算、日期计算、校验、保存和通知调度。
-   **用户可控：** AI
    生成的数据先进入草稿确认流程；重要数据不得在没有确认的情况下被静默新增、覆盖或删除。
-   **单一业务入口：** 手动录入与 AI 录入最终调用同一套业务服务和
    Repository。
-   **数据可迁移：** 核心实体使用
    UUID；保留创建时间、更新时间和软删除字段，为未来同步准备。
-   **逐步交付：** 先完成可靠的本地功能，再引入 AI、云端和复杂自动化。

## 2. 产品信息架构

### 2.1 五个底部导航入口

1.  **首页 Home：** 今日收支、待办数量、近期日程、AI 提醒、快速记录。
2.  **记账 Ledger：** 收入与支出流水、分类、账户、预算和统计。
3.  **计划 Planner：** 待办列表、日历事件、每日记录。
4.  **AI 助手 Assistant：** 自然语言记账、事项提取、数据问答和总结。
5.  **我的 Settings：** 分类与账户设置、提醒偏好、AI
    设置、备份导出、隐私说明。

首页要回答"我现在应该关注什么"；AI
助手要回答"我能不能直接说出来，让应用帮我整理"。

### 2.2 三类生活记录

#### Task：待办事项

有明确完成目标，可设置优先级、截止日期/时间、完成状态和提醒。

#### Event：日程事件

发生在某个时间点或时间段的事件，可设置开始时间、结束时间、是否全天、地点和重复规则。

#### JournalEntry：每日记录

记录已经发生的事情、想法和进展，不一定有截止时间，也不默认生成提醒。

三者允许关联，但不能混为一个实体。完成待办后可以询问用户是否将完成情况写入日记；不得未经允许自动生成长篇日记。

## 3. 产品需求

### 3.1 智能记账

第一版目标： - 手动新增、编辑、删除收入与支出。 - 支持账户和分类。 -
支持备注、商家、实际发生日期。 - 支持按日、月查看流水。 -
支持月度收入、支出、结余及分类统计。 - 提供基础预算及预算使用进度。 -
支持自然语言生成单笔或多笔账目草稿。 - 允许用户修改 AI
识别出的金额、分类、账户、日期和备注。 -
未来扩展转账、退款、周期账单和跨币种处理。

交易类型必须明确区分： - `expense`：支出。 - `income`：收入。 -
`transfer`：账户间转账，不计入收入或支出。 -
`refund`：退款，应关联原交易并冲减对应支出。

第一版 UI 可以先重点完成 CNY
收入/支出，但数据库模型应避免把类型和金额正负混为一谈。当前第一周代码已包含交易类型字段，但多币种、退款和转账完整业务流程仍未完成。

### 3.2 事项与日程

-   创建、编辑、完成、恢复和删除待办。
-   设置截止日期和优先级。
-   创建日程事件和全天事件。
-   提供按日期浏览的日历/时间线。
-   支持每日记录的新增、编辑和历史查看。
-   支持基础的每日、每周、每月重复规则。
-   事项和事件可配置一个或多个提醒。

### 3.3 AI 解析与提醒

-   自然语言意图识别。
-   提取交易金额、币种、分类、日期、账户、商家和备注。
-   提取任务标题、截止日期、事件时间及提醒提前量。
-   一次输入支持多条记录。
-   日期解析必须结合当前时间、用户时区和语言设置。
-   模糊表达应触发澄清，不可凭空补全关键字段。
-   AI 输出必须通过结构和业务校验，再显示确认界面。
-   本地通知由确定性调度器执行，而不是依赖模型在后台持续运行。
-   AI 不可用时，手动记账、事项和日记仍须正常工作。

### 3.4 数据分析

-   日、周、月收支汇总。
-   分类支出占比。
-   预算使用率。
-   与上一周期对比。
-   每日/每周总结。
-   AI
    分析只能依据数据库查询得到的真实统计数据；金额、总和和百分比由程序计算，不能让模型自由估算。

## 4. MVP 范围与非目标

### 4.1 MVP 必须完成

-   五个主导航页面及基本路由。
-   本地 SQLite 数据持久化。
-   手动记账和基础统计。
-   待办创建、完成和查询。
-   每日记录新增与查询。
-   本地提醒机制及提醒状态管理。
-   AI 自然语言解析草稿、校验、确认和保存。
-   基础预算。
-   数据导出/备份方案。
-   数据库迁移和基本测试。

### 4.2 暂不纳入第一版

-   银行账户自动连接。
-   自动导入第三方支付账单。
-   持续后台监听或唤醒词。
-   未经用户授权的自动化微信控制。
-   多用户共享账本。
-   完整云端同步。
-   复杂多智能体系统。
-   自动删除/覆盖用户记录。
-   复杂借贷、应收应付和跨币种汇兑管理。

## 5. 技术选型与系统架构

### 5.1 推荐技术栈

  ------------------------------------------------------------------------------------------
  层级                    技术                            用途
  ----------------------- ------------------------------- ----------------------------------
  手机端                  Flutter / Dart                  一套代码覆盖 Android 与 iOS

  状态管理                Riverpod                        状态管理、依赖注入、响应式数据

  路由                    go_router                       页面导航与底部导航分支

  本地数据库              SQLite + Drift                  事务、类型安全查询、响应式数据流

  网络请求                Dio 或统一 HTTP 客户端          AI API 调用、超时和错误处理

  本地通知                flutter_local_notifications +   本地通知和时区处理
                          timezone                        

  后端                    Python + FastAPI                AI 代理、解析、分析接口

  Schema 校验             Pydantic                        校验 AI 与 API 数据

  大模型                  可替换的模型 API 适配层         自然语言解析与总结

  未来云数据库            PostgreSQL                      多端同步与远程数据

  未来后台任务            持久化任务队列/调度器           云端提醒、周期任务
  ------------------------------------------------------------------------------------------

### 5.2 系统结构

``` text
Flutter Mobile App
├── Presentation
│   ├── Home
│   ├── Ledger
│   ├── Planner
│   ├── AI Assistant
│   └── Settings
├── Application / Domain
│   ├── TransactionService
│   ├── TaskService
│   ├── EventService
│   ├── JournalService
│   └── ReminderService
├── Data
│   ├── Repository Interfaces
│   └── Drift / SQLite
├── Local Notification Scheduler
└── Network
    └── AI Gateway
        └── FastAPI
            ├── AI Parse
            ├── AI Insights
            ├── Model Provider Adapter
            └── Validation / Rate Limiting
```

### 5.3 数据流

手动记账：
`表单 → 前端校验 → TransactionService → SQLite 事务 → 页面统计更新`

AI 记账：
`自然语言 → FastAPI / 大模型 → 结构化 JSON → 客户端结构与业务校验 → 草稿确认 → TransactionService → SQLite`

提醒：
`Task/Event/账单规则 → Reminder 记录 → 本地调度器 → 系统通知 → 用户完成/延后/关闭`

### 5.4 关键架构约束

-   AI API 密钥不能硬编码在移动端，必须保存在服务端。
-   基础 CRUD 不应依赖网络。
-   AI 后端默认只接收完成任务所必需的数据，不上传全部历史日记。
-   本地通知必须由可恢复的持久化状态驱动；应用重启后需重新核对并安排通知。
-   为未来同步预留 UUID、更新时间和软删除，但不要在 MVP
    阶段提前实现复杂同步。
-   iOS 构建和真机测试需要 macOS + Xcode；Windows 可先完成 Android
    开发。

## 6. 数据库设计

第一周工程中的初始表： - `accounts` - `categories` -
`ledger_transactions` - `tasks` - `events` - `journal_entries` -
`reminders` - `app_settings`

第一周代码当前 schemaVersion 为
1。所有后续结构修改必须增加数据库迁移，禁止通过清空数据库规避迁移问题。

### 6.1 Account

建议字段： - `id`：UUID 主键。 - `name`：账户名称。 -
`currency`：币种代码。 -
`opening_balance_minor`：期初余额，以币种最小单位存储。 -
`created_at`、`updated_at`。 - 可选 `is_archived`。

### 6.2 Category

-   `id`
-   `name`
-   `type`：income / expense
-   `parent_id`：可空，支持两级分类。
-   `sort_order`
-   可选 `icon`、`color`、`is_system`、`is_enabled`

### 6.3 Transaction

建议字段： - `id`：UUID。 - `kind`：expense / income / transfer /
refund。 - `amount_minor`：非负整数金额，使用币种最小单位。 -
`currency`：币种代码。 - `account_id`：来源/主要账户。 -
`target_account_id`：转账目标账户，可空。 -
`category_id`：分类，可空。 - `refund_of_id`：退款对应的原交易，可空。 -
`local_date`：用户当地日期，用于日期统计。 -
`occurred_at_utc`：准确发生时间，可空。 - `time_precision`：day /
minute。 - `timezone`：原始时区标识。 - `merchant`、`note`。 -
`source`：manual / ai / import。 - `source_draft_id`：AI
草稿幂等标识。 - `created_at`、`updated_at`、`deleted_at`。

金额以整数存储，避免浮点误差。不同币种的小数位数不同，不能一律乘以
100。`created_at` 表示创建记录的时间；`local_date`/`occurred_at_utc`
表示实际发生时间，补记历史消费时不能混淆。

### 6.4 Task

-   `id`
-   `title`
-   `details`
-   `status`：todo / doing / done / cancelled
-   `priority`
-   `due_date`：纯日期
-   `due_at_utc`：精确截止时间，可空
-   `completed_at`
-   `created_at`、`updated_at`、`deleted_at`

### 6.5 Event

-   `id`
-   `title`
-   `description`
-   `event_date`
-   `starts_at_utc`、`ends_at_utc`
-   `all_day`
-   `timezone`
-   `recurrence_rule_id`
-   `created_at`、`updated_at`

### 6.6 JournalEntry

-   `id`
-   `journal_date`
-   `title`
-   `content`
-   `mood`（可选）
-   `created_at`、`updated_at`、`deleted_at`

### 6.7 Reminder

-   `id`
-   `entity_type`
-   `entity_id`
-   `remind_at_utc`
-   `status`：scheduled / delivered / dismissed / cancelled
-   `notification_id`
-   `snoozed_until`
-   `created_at`、`updated_at`

### 6.8 AppSettings

使用键值形式保存默认币种、时区、默认提醒提前量、每日总结时间、预算阈值、AI
开关和隐私偏好等。

### 6.9 后续建议增加的表

-   `category_rules`：用户自定义分类规则。
-   `budgets`：月度或分类预算。
-   `recurring_transactions`：周期账单模板。
-   `transaction_tags`：账目标签关联。
-   `transaction_drafts`：需要跨会话恢复的 AI 草稿（可选）。

### 6.10 资金统计规则

-   支出减少账户余额并计入支出。
-   收入增加账户余额并计入收入。
-   转账使转出账户减少、转入账户增加，但不计入收入或支出。
-   退款关联原交易，并冲减原支出。
-   同一笔支出的退款总额不能超过允许的退款范围，避免重复冲减。
-   跨币种汇总必须有明确汇率来源；MVP 可限制为同币种统计。

## 7. 智能记账分类体系

### 7.1 默认支出分类

-   餐饮：早餐、午餐、晚餐、外卖、零食、饮品。
-   交通：公交地铁、打车、火车、机票、加油、停车。
-   购物：日用品、服饰、电子产品、其他购物。
-   住房：房租、水电燃气、物业、维修。
-   学习：教材、课程、考试、文具、学习软件。
-   娱乐：游戏、电影、聚会、旅游。
-   健康：医疗、药品、体检、健身。
-   通讯及订阅：手机话费、宽带、会员订阅。
-   人情往来：礼物、红包、聚餐请客。
-   其他：未分类支出。

### 7.2 默认收入分类

-   工作收入：工资、兼职、劳务。
-   奖励收入：奖学金、奖金、活动奖励。
-   投资收入：利息、分红。
-   其他收入：礼金、其他收入。

转账和退款使用交易类型表达，不直接归为普通收入分类。

### 7.3 分类优先级

1.  用户在当前输入中明确指定的分类。
2.  用户自定义分类规则。
3.  高确定性关键词规则。
4.  已确认的历史分类习惯。
5.  AI 语义判断。
6.  不确定时标记待确认或归入"其他"，不得伪装为高置信结果。

分类依据以消费用途为主，而不是支付渠道。支付方式、账户和消费分类应是独立字段。

建议 `CategoryRule` 包含： - `id` - `pattern` - `match_type`：keyword /
merchant / exact - `category_id` - `priority` - `is_enabled` -
`created_at`

## 8. 自然语言识别流程

### 8.1 流程

1.  接收文本、当前时间、时区、语言、默认币种、可用分类和账户。
2.  判断意图：创建交易、计划消费、周期账单、查询或分析。
3.  解析交易类型、金额、币种、日期、时间精度、分类、账户、商家和备注。
4.  返回符合 Schema 的 JSON 草稿。
5.  客户端校验字段和业务规则。
6.  检查重复提交与疑似重复交易。
7.  展示可编辑确认卡片。
8.  用户确认后调用统一 `TransactionService` 保存。
9.  通过数据库事务写入并刷新统计。

### 8.2 意图示例

  ---------------------------------------------------------------------------
  输入                     意图                    处理
  ------------------------ ----------------------- --------------------------
  今天午饭 28 元           create_transactions     支出草稿

  工资到账 3500            create_transactions     收入草稿

  银行卡转微信 500         create_transactions     转账草稿

  上次订单退款 30          create_transactions     退款草稿，尝试关联原交易

  我准备买 3000 元电脑     planned_expense         不计入已发生支出

  每月 15 号交 1200 元房租 create_recurring_rule   周期账单草稿

  本月交通费多少           query_transactions      查询本地数据库

  上个月餐饮是不是增加了   analyze_transactions    程序计算数据，AI 解释
  ---------------------------------------------------------------------------

### 8.3 日期规则

-   请求必须包含当前时间、用户时区和语言设置。
-   "昨天"只决定日期，不应自动生成精确到分钟的时间。
-   未提供时间时，允许使用默认日期，但不应凭空补出具体时刻。
-   "月底前"等模糊截止日期按产品规则处理，必要时向用户澄清。
-   处理重复日期时考虑月底、闰年、时区变化和夏令时。
-   对跨午夜、跨月和跨年输入编写测试。

### 8.4 金额与重复识别

-   金额由确定性解析和模型理解共同完成，但最终必须校验。
-   API 中金额使用十进制字符串，客户端按币种精度转换为整数最小单位。
-   "总额 100，其中水果 30、日用品 70"不能累计成 200。
-   "午餐 28，打车 16"应生成两笔记录。
-   同一草稿重复提交通过唯一 `source_draft_id` 阻止。
-   相似金额/分类/时间仅触发疑似重复提示，不自动删除真实交易。
-   "打算花钱"与"已经花钱"必须区分。
-   不明确的"转给朋友"不能自动判定为一般消费。

### 8.5 AI 输出的安全边界

-   AI 不能直接写入数据库。
-   模型输出必须经过 Pydantic 和客户端业务校验。
-   分类 ID 必须来自当前用户的合法分类集合。
-   账户、金额、日期不确定时应允许澄清。
-   所有 AI 草稿默认需用户确认。
-   统计数值由程序计算，AI 只解释。
-   AI 服务不可用时，手动记账必须继续可用。

## 9. API 设计

### 9.1 原则

本地账目 CRUD 通过 Repository 访问 Drift/SQLite；远程 API 主要用于 AI
解析和分析。第一版不必为每笔本地交易都调用服务器。

基础路径：`/api/v1`

### 9.2 API 清单

  API / 方法                               位置              作用
  ---------------------------------------- ----------------- --------------
  `createTransaction()`                    本地 Repository   新增交易
  `updateTransaction()`                    本地 Repository   修改交易
  `deleteTransaction()`                    本地 Repository   软删除交易
  `listTransactions(filter)`               本地 Repository   查询流水
  `getLedgerSummary(start,end,currency)`   本地 Repository   收支汇总
  `getCategoryBreakdown(period)`           本地 Repository   分类统计
  `getBudgetStatus(period)`                本地 Repository   预算状态
  `confirmDrafts(drafts)`                  本地 Repository   批量确认草稿
  `POST /api/v1/ai/ledger/parse`           FastAPI           自然语言解析
  `POST /api/v1/ai/ledger/insights`        FastAPI           消费分析
  `GET /api/v1/health`                     FastAPI           服务健康检查

### 9.3 解析请求示例

``` json
{
  "request_id": "req-001",
  "text": "今天午饭花了28元，晚上打车16元",
  "now": "2026-10-20T10:21:00+08:00",
  "timezone": "Asia/Shanghai",
  "locale": "zh-CN",
  "default_currency": "CNY",
  "categories": [
    {"id": "cat_food", "name": "餐饮"},
    {"id": "cat_transport", "name": "交通"}
  ],
  "accounts": [
    {"id": "acc_wallet", "name": "现金", "currency": "CNY"}
  ]
}
```

### 9.4 解析响应示例

``` json
{
  "schema_version": "1.0",
  "request_id": "req-001",
  "intent": "create_transactions",
  "items": [
    {
      "draft_key": "item-1",
      "type": "expense",
      "amount": "28.00",
      "currency": "CNY",
      "category_id": "cat_food",
      "account_id": null,
      "local_date": "2026-10-20",
      "occurred_local_time": null,
      "time_precision": "day",
      "merchant": null,
      "note": "午饭",
      "needs_review": false,
      "missing_fields": []
    }
  ],
  "requires_confirmation": true,
  "warnings": []
}
```

上述数据仅为格式示例。实际日期应由请求上下文和解析逻辑决定。

### 9.5 错误处理

统一返回： - `400`：请求格式错误。 -
`401`：认证失败（部署需要认证时）。 - `422`：结构或业务校验失败。 -
`429`：请求过频。 - `500/503`：服务端或模型服务不可用。

客户端应提供重试和手动录入降级方案，不应因为 AI 超时丢失用户原始文本。

### 9.6 未来同步接口

未来可增加： - `POST /api/v1/auth/login` - `POST /api/v1/sync/push` -
`GET /api/v1/sync/pull` - `POST /api/v1/sync/resolve`

同步需要版本号、变更游标、软删除标记和冲突解决策略；不得仅根据更新时间直接覆盖另一设备的数据。

## 10. 页面交互

### 首页

-   今日支出、本月累计。
-   今日待办和即将到期事项。
-   近期日程。
-   AI 提醒卡片。
-   快速记账、快速记录入口。

### 记账页

-   月收入、月支出、结余、预算进度。
-   账目流水与筛选。
-   新增账目：手动表单 / AI 自然语言。
-   账目详情、编辑和删除。

### 计划页

-   待办列表。
-   日历。
-   每日记录。
-   按日期查看任务、事件和日志。

### AI 助手

-   自然语言输入。
-   结构化结果卡片。
-   修改、确认、取消。
-   历史数据问答和总结。
-   不得只显示一段聊天文字而不展示即将执行的结构化操作。

### 我的

-   账户和分类管理。
-   默认币种和提醒偏好。
-   AI 设置、隐私说明。
-   数据导出与备份恢复。
-   版本信息。

## 11. 代码结构建议

``` text
lifepilot/
├── lib/
│   ├── app/
│   │   ├── lifepilot_app.dart
│   │   └── router.dart
│   ├── core/
│   │   ├── database/
│   │   ├── providers.dart
│   │   └── utils/
│   ├── features/
│   │   ├── home/
│   │   ├── ledger/
│   │   ├── planner/
│   │   ├── assistant/
│   │   └── settings/
│   ├── shared/
│   └── main.dart
├── backend/
│   └── app/
├── docs/
├── test/
├── pubspec.yaml
└── AGENT.md
```

建议业务调用路径：
`Page → Provider/Controller → Service → Repository → Database`

页面中不要直接堆叠数据库写入和复杂业务规则。手动输入和 AI
确认必须调用同一个业务服务。

## 12. 开发路线图

### 第 1 周：工程骨架

-   Flutter 工程、Material 3。
-   五个底部导航和基础路由。
-   Riverpod。
-   Drift/SQLite。
-   账户、分类、账目、待办、事件、日记、提醒、设置基础表。
-   手动记账、待办和日记的基础读写。
-   基础测试与工程文档。

### 第 2 周：完善记账模块

-   交易编辑、账户管理、分类管理。
-   收入/支出分类规则。
-   月度统计和分类统计。
-   预算基础功能。
-   金额、退款、转账规则测试。
-   数据库迁移和删除行为完善。

### 第 3 周：完善事项与日记

-   Task/Event/Journal CRUD。
-   日历与时间线。
-   日期筛选、搜索。
-   基础重复规则。

### 第 4 周：提醒系统

-   本地通知权限。
-   提前提醒、延后、取消。
-   事项变更后的通知重排。
-   重启恢复和时区测试。

### 第 5 周：AI 接入

-   FastAPI。
-   大模型 Provider 适配层。
-   自然语言解析。
-   结构化 Schema 与业务验证。
-   草稿确认流程。
-   AI 问答基础版。

### 第 6 周：整合和发布准备

-   首页汇总和每日总结。
-   备份/导出。
-   隐私说明。
-   错误处理与离线测试。
-   Android 测试包和 iOS 环境验证。

预估 6--8 周，实际取决于投入时间、UI 精细程度和 AI 调试情况。

## 13. 测试与验收标准

### 13.1 基础功能

-   五个导航正常切换。
-   记账、待办、日记保存后重启仍存在。
-   删除/完成状态能正确刷新 UI。
-   月度统计在新增、编辑、删除后保持一致。
-   转账不重复计入收入或支出。
-   退款关联原交易并正确冲减。

### 13.2 AI

-   单笔与多笔账目解析。
-   缺少金额或币种。
-   模糊分类。
-   相对日期、跨月日期。
-   周期账单。
-   总金额与明细不重复累计。
-   "计划消费"不被记为已发生支出。
-   同一草稿重复提交不产生重复交易。
-   AI 不可用时手动记账仍正常。

### 13.3 时间与通知

-   午夜跨日、月底、闰年。
-   每月 29/30/31 日的重复规则。
-   设备时区变化。
-   通知权限关闭。
-   应用重启后的通知恢复。
-   编辑或删除事项后取消旧提醒。

### 13.4 隐私与可靠性

-   API 密钥不在客户端。
-   不默认上传全部日记。
-   数据库迁移不静默清空数据。
-   AI 失败不丢失原始输入。
-   导出与恢复有效。
-   重要写入使用事务与幂等键。

## 14. 第一周工程现状与注意事项

第一周源码包为 `LifePilot_Week1_Source.zip`，解压后项目目录为
`lifepilot/`。

当前工程基线： - Flutter + Dart。 - Material 3。 - Riverpod。 -
go_router。 - Drift / SQLite。 - 五个底部导航入口。 -
初始数据表：accounts、categories、ledger_transactions、tasks、events、journal_entries、reminders、app_settings。 -
schemaVersion = 1。 - 已有基础手动记账、待办和日记读写。 - AI
与提醒调度目前是占位/未接入状态。 -
完整账户与分类管理、预算、账目编辑、日历事件管理、备份恢复和多端同步尚未完成。

源码包不包含 Flutter 自动生成的 `android/`、`ios/` 平台工程和 Drift 的
`*.g.dart` 文件。首次运行需要在本地生成：

``` powershell
flutter create --project-name lifepilot --platforms=android,ios --org com.example .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

执行 `flutter create` 时不要使用 `--overwrite` 覆盖已有 `lib/` 和
`pubspec.yaml`。iOS 构建需要 macOS + Xcode。源码尚需在真实 Flutter SDK
环境中完成编译和测试验证。

## 15. 下一步建议

按以下顺序推进：

1.  在本地完成第一周工程初始化、依赖安装、代码生成、静态检查和测试。
2.  修复所有编译错误和测试失败，确认 Android 可以运行。
3.  先完善记账基础数据层和手动录入流程。
4.  再增加分类规则、预算、退款与转账业务。
5.  最后接入 AI 解析接口，并确保 AI 草稿经过统一校验和确认后才保存。

**MVP 的完成标准不是"有一个 AI 聊天窗口"，而是记账闭环、事项闭环和 AI
录入闭环都能可靠运行。**
