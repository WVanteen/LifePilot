import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_statistics_service.dart';

void main() {
  test(
    'period statistics exclude transfers and deleted records and apply refunds to original category',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.seedDefaults();
      Future<void> add(
        String id,
        String kind,
        int amount,
        String date, {
        String? original,
        String? category,
        int? deleted,
      }) async {
        await db
            .into(db.ledgerTransactions)
            .insert(
              LedgerTransactionsCompanion.insert(
                id: id,
                kind: kind,
                amountMinor: amount,
                accountId: 'acc_cash',
                localDate: date,
                categoryId: Value(category),
                refundOfId: Value(original),
                deletedAt: Value(deleted),
                createdAt: 1,
                updatedAt: 1,
              ),
            );
      }

      await add(
        'expense',
        'expense',
        10000,
        '2026-09-30',
        category: 'cat_food',
      );
      await add(
        'income',
        'income',
        20000,
        '2026-10-01',
        category: 'cat_salary',
      );
      await add('spend', 'expense', 5000, '2026-10-02', category: 'cat_food');
      await add('refund', 'refund', 1200, '2026-10-03', original: 'expense');
      await add('transfer', 'transfer', 9999, '2026-10-03');
      await add(
        'deleted',
        'expense',
        3000,
        '2026-10-03',
        category: 'cat_food',
        deleted: 1,
      );
      final service = LedgerStatisticsService(db);
      final month = await service
          .watch(DateTime(2026, 10), DateTime(2026, 11))
          .first;
      expect(month.total.income, 20000);
      expect(month.total.expense, 3800);
      expect(month.total.balance, 16200);
      expect(month.categories['cat_food']!.expense, 3800);
      expect(month.accounts['acc_cash']!.expense, 3800);
      expect(month.daily['2026-10-03']!.expense, -1200);
      final day = await service
          .watch(DateTime(2026, 10, 2), DateTime(2026, 10, 3))
          .first;
      expect(day.total.expense, 5000);
      final year = await service.watch(DateTime(2026), DateTime(2027)).first;
      expect(year.total.expense, 13800);
    },
  );
}
