import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/home/home_page.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';
import 'package:lifepilot/features/ledger/transfer_refund_service.dart';

void main() {
  testWidgets('首页本月支出随退款、删除和恢复更新', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final ledger = LedgerRepository(db);
    final service = TransferRefundService(db);
    final expense = await ledger.addManual(
      kind: 'expense',
      amount: '220',
      categoryId: 'cat_food',
      transactionDate: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥220.00'), findsOneWidget);
    final refund = await service.addRefund(
      operationId: 'home-refund',
      expenseId: expense,
      amountMinor: 3000,
      date: DateTime.now(),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥190.00'), findsOneWidget);
    await service.delete(refund);
    await tester.pumpAndSettle();
    expect(find.text('¥220.00'), findsOneWidget);
    await service.restore(refund);
    await tester.pumpAndSettle();
    expect(find.text('¥190.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
