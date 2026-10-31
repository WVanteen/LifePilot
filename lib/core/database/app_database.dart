import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Categories,
  LedgerTransactions,
  Tasks,
  Events,
  JournalEntries,
  Reminders,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lifepilot'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from != 1 || to != 2) {
            throw StateError('Database migration missing: $from -> $to');
          }
          await transaction(() async {
            await m.addColumn(accounts, accounts.accountType);
            await m.addColumn(accounts, accounts.isActive);
            await m.addColumn(categories, categories.iconKey);
            await m.addColumn(categories, categories.isActive);
          });
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> seedDefaults() async {
    await transaction(() async {
      final accountsExisting = await (select(accounts)..limit(1)).get();
      if (accountsExisting.isEmpty) {
        await into(accounts).insert(AccountsCompanion.insert(
          id: 'acc_cash',
          name: '现金',
          createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        ));
      }
      final categoriesExisting = await (select(categories)..limit(1)).get();
      if (categoriesExisting.isEmpty) {
        const seeds = <(String, String, String)>[
          ('cat_food', '餐饮', 'expense'),
          ('cat_transport', '交通', 'expense'),
          ('cat_shopping', '购物', 'expense'),
          ('cat_housing', '住房', 'expense'),
          ('cat_study', '学习', 'expense'),
          ('cat_fun', '娱乐', 'expense'),
          ('cat_health', '健康', 'expense'),
          ('cat_other_expense', '其他支出', 'expense'),
          ('cat_salary', '工资', 'income'),
          ('cat_bonus', '奖金', 'income'),
          ('cat_other_income', '其他收入', 'income'),
        ];
        for (var i = 0; i < seeds.length; i++) {
          final (id, name, type) = seeds[i];
          await into(categories).insert(CategoriesCompanion.insert(
            id: id,
            name: name,
            type: type,
            sortOrder: Value(i),
          ));
        }
      }
    });
  }
}
