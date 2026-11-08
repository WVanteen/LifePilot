import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_detail_pages.dart';

const entry = LedgerTransaction(
  id: 'entry',
  kind: 'expense',
  amountMinor: 1234,
  currency: 'CNY',
  accountId: 'account',
  categoryId: 'category',
  localDate: '2026-11-01',
  timePrecision: 'day',
  timezone: 'local',
  source: 'manual',
  merchant: '商家测试',
  note: '备注测试',
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  testWidgets('详情展示商家、历史账户和分类', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerDetailPage(
          transaction: Stream.value(entry),
          accountNames: const {'account': '旧账户'},
          categoryNames: const {'category': '旧分类'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('账目详情'), findsOneWidget);
    expect(find.text('商家测试'), findsOneWidget);
    expect(find.text('旧账户'), findsOneWidget);
    expect(find.text('旧分类'), findsOneWidget);
  });

  testWidgets('回收站恢复时调用回调', (tester) async {
    String? restored;
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerRecycleBinPage(
          transactions: Stream.value([entry]),
          accountNames: const {'account': '旧账户'},
          categoryNames: const {'category': '旧分类'},
          onRestore: (id) async {
            restored = id;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pump();
    expect(restored, 'entry');
    expect(find.text('账目已恢复'), findsOneWidget);
  });

  testWidgets('回收站显示恢复失败', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerRecycleBinPage(
          transactions: Stream.value([entry]),
          accountNames: const {},
          categoryNames: const {},
          onRestore: (_) async => throw StateError('无法恢复'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pump();
    expect(find.textContaining('恢复失败'), findsOneWidget);
  });
}
