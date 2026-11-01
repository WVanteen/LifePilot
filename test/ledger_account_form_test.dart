import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/accounts/account_repository.dart';
import 'package:lifepilot/features/ledger/add_transaction_sheet.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  testWidgets('new entry follows default and hides inactive accounts', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final repo = AccountRepository(db);
    final id = await repo.create(
      name: '微信账户',
      accountType: 'wechat',
      currency: 'CNY',
      openingBalanceMinor: 1234,
      makeDefault: true,
    );
    final inactive = await repo.create(
      name: '停用账户',
      accountType: 'bank',
      currency: 'CNY',
      openingBalanceMinor: 0,
    );
    await repo.deactivate(inactive);
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAddTransactionSheet(context),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.textContaining('微信账户 · 微信 · 默认'), findsOneWidget);
    expect(find.text('余额：¥12.34'), findsOneWidget);
    await tester.tap(find.textContaining('微信账户 · 微信 · 默认'));
    await tester.pumpAndSettle();
    expect(find.textContaining('停用账户'), findsNothing);
    await tester.tap(find.textContaining('现金 · 现金').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('现金 · 现金'), findsOneWidget);
    Navigator.of(tester.element(find.text('新增账目'))).pop();
    await tester.pumpAndSettle();
    await repo.setDefault('acc_cash');
    expect((await repo.getDefault())!.id, isNot(id));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.textContaining('现金 · 现金 · 默认'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('editing retains original inactive account and excludes others', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final accounts = AccountRepository(db);
    final ledger = LedgerRepository(db);
    final original = await accounts.create(
      name: '原微信',
      accountType: 'wechat',
      currency: 'CNY',
      openingBalanceMinor: 0,
    );
    final other = await accounts.create(
      name: '其他停用',
      accountType: 'bank',
      currency: 'CNY',
      openingBalanceMinor: 0,
    );
    final id = await ledger.addManual(
      kind: 'expense',
      amount: '10',
      categoryId: 'cat_food',
      accountId: original,
    );
    await accounts.deactivate(original);
    await accounts.deactivate(other);
    final transaction = await db.select(db.ledgerTransactions).getSingle();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTransactionSheet(context, transaction: transaction),
                child: const Text('编辑'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.textContaining('原微信 · 微信 · 已停用'), findsOneWidget);
    await tester.tap(find.textContaining('原微信 · 微信 · 已停用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('其他停用'), findsNothing);
    await tester.tap(find.textContaining('原微信 · 微信 · 已停用').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() async {
      expect((await ledger.watchEntries().first).single.accountId, original);
      await expectLater(
        ledger.updateManual(
          id: id,
          kind: 'expense',
          amount: '10',
          categoryId: 'cat_food',
          accountId: other,
          transactionDate: DateTime.now(),
        ),
        throwsFormatException,
      );
    });
  });
}
