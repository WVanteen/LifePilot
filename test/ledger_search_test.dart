import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/ledger/ledger_page.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  testWidgets('流水可按备注或商家关键词筛选', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final repo = LedgerRepository(db);
    await repo.addManual(
      kind: 'expense',
      amount: '12',
      categoryId: 'cat_food',
      note: '独特备注火锅',
      merchant: '商家甲',
    );
    await repo.addManual(
      kind: 'expense',
      amount: '23',
      categoryId: 'cat_transport',
      note: '打车',
      merchant: '独特商家乙',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: LedgerPage())),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, '搜索商家或备注');
    await tester.ensureVisible(search);
    await tester.enterText(search, '备注火锅');
    await tester.pumpAndSettle();
    expect(find.textContaining('独特备注火锅'), findsOneWidget);
    expect(find.textContaining('打车'), findsNothing);
    await tester.enterText(search, '商家乙');
    await tester.pumpAndSettle();
    expect(find.textContaining('打车'), findsOneWidget);
    expect(find.textContaining('独特备注火锅'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
