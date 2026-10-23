import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late LedgerRepository repository;
  late bool sharedDatabaseClosed;

  setUp(() async {
    sharedDatabaseClosed = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    repository = LedgerRepository(db);
  });

  tearDown(() async {
    if (!sharedDatabaseClosed) await db.close();
  });

  test(
    'manual ledger supports create, edit, filter, delete and restore',
    () async {
      final expenseId = await repository.addManual(
        kind: 'expense',
        amount: '28.50',
        categoryId: 'cat_food',
        transactionDate: DateTime(2026, 10, 5),
        note: '午饭',
      );
      await repository.addManual(
        kind: 'income',
        amount: '100.00',
        categoryId: 'cat_other_income',
        transactionDate: DateTime(2026, 10, 6),
      );

      await repository.updateManual(
        id: expenseId,
        kind: 'expense',
        amount: '30.25',
        categoryId: 'cat_transport',
        accountId: 'acc_cash',
        transactionDate: DateTime(2026, 10, 4),
        note: '公交卡充值',
      );

    final allEntries = await repository.watchEntries().first;
    expect(allEntries.map((entry) => entry.localDate), [
      '2026-10-06',
      '2026-10-04',
    ]);

      final expenses = await repository
          .watchEntries(
            kind: 'expense',
            categoryId: 'cat_transport',
            fromDate: DateTime(2026, 10, 1),
            toDate: DateTime(2026, 10, 31),
          )
          .first;
      expect(expenses, hasLength(1));
      expect(expenses.single.id, expenseId);
      expect(expenses.single.amountMinor, 3025);
      expect(expenses.single.localDate, '2026-10-04');
      expect(expenses.single.note, '公交卡充值');

      await repository.softDelete(expenseId);
      expect(await repository.watchEntries().first, hasLength(1));
      await repository.restore(expenseId);
      expect(await repository.watchEntries().first, hasLength(2));
    },
  );

  test('month summary and category expenses use integer minor units', () async {
    await repository.addManual(
      kind: 'income',
      amount: '100.00',
      categoryId: 'cat_salary',
      transactionDate: DateTime(2026, 10, 1),
    );
    await repository.addManual(
      kind: 'expense',
      amount: '28.50',
      categoryId: 'cat_food',
      transactionDate: DateTime(2026, 10, 2),
    );
    await repository.addManual(
      kind: 'expense',
      amount: '10.25',
      categoryId: 'cat_food',
      transactionDate: DateTime(2026, 10, 3),
    );
    await repository.addManual(
      kind: 'expense',
      amount: '6.00',
      categoryId: 'cat_transport',
      transactionDate: DateTime(2026, 9, 30),
    );

    final summary = await repository
        .watchMonthSummary(DateTime(2026, 10))
        .first;
    expect(summary.incomeMinor, 10000);
    expect(summary.expenseMinor, 3875);
    expect(summary.balanceMinor, 6125);

    final breakdown = await repository
        .watchMonthExpenseByCategory(DateTime(2026, 10))
        .first;
    expect(breakdown, hasLength(1));
    expect(breakdown.single.categoryId, 'cat_food');
    expect(breakdown.single.amountMinor, 3875);
  });

  test(
    'invalid references roll back without inserting a transaction',
    () async {
      await expectLater(
        repository.addManual(
          kind: 'expense',
          amount: '12.00',
          categoryId: 'cat_salary',
        ),
        throwsFormatException,
      );
      await expectLater(
        repository.addManual(
          kind: 'expense',
          amount: '12.00',
          categoryId: 'cat_food',
          accountId: 'missing-account',
        ),
        throwsFormatException,
      );
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    },
  );

  test('schema version remains one when no migration is required', () async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), 1);
  });

  test('file database keeps ledger data after close and reopen', () async {
    await db.close();
    sharedDatabaseClosed = true;
    final directory = await Directory.systemTemp.createTemp('lifepilot_test_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}ledger.sqlite',
    );
    AppDatabase? first;
    AppDatabase? second;
    try {
      first = AppDatabase.forTesting(NativeDatabase(file));
      await first.seedDefaults();
      await LedgerRepository(first).addManual(
        kind: 'income',
        amount: '88.00',
        categoryId: 'cat_other_income',
        transactionDate: DateTime(2026, 10, 7),
      );
      await first.close();
      first = null;

      second = AppDatabase.forTesting(NativeDatabase(file));
      final rows = await LedgerRepository(second).watchEntries().first;
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 8800);
    } finally {
      await first?.close();
      await second?.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });
}
