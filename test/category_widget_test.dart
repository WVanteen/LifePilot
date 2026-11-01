import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/categories/categories_page.dart';
import 'package:lifepilot/features/categories/category_repository.dart';
import 'package:lifepilot/features/ledger/add_transaction_sheet.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  testWidgets(
    'category management creates, edits, reorders and toggles a category',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.seedDefaults();
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: CategoriesPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('收入分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增分类'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '分类名称'),
        '测试分类',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('测试分类'), findsOneWidget);
      final tile = find.ancestor(
        of: find.text('测试分类'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('上移'));
      await tester.pumpAndSettle();
      final rows = await tester.runAsync(
        () => CategoryRepository(db).watch(type: 'income').first,
      );
      expect(rows![rows.length - 2].name, '测试分类');
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '分类名称'),
        '修改分类',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final changedTile = find.ancestor(
        of: find.text('修改分类'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: changedTile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();
      expect(find.text('停用分类？'), findsOneWidget);
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: changedTile, matching: find.text('已停用')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: changedTile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: changedTile, matching: find.text('启用')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets('category page separates income and expense', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CategoriesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.text('收入分类'));
    await tester.pumpAndSettle();
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('new and historical forms filter inactive categories', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final repo = CategoryRepository(db);
    final ledger = LedgerRepository(db);
    await ledger.addManual(
      kind: 'expense',
      amount: '10',
      categoryId: 'cat_food',
    );
    final entry = await db.select(db.ledgerTransactions).getSingle();
    await repo.setActive('cat_food', false);
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showAddTransactionSheet(context),
                    child: const Text('新增'),
                  ),
                  TextButton(
                    onPressed: () =>
                        showTransactionSheet(context, transaction: entry),
                    child: const Text('历史'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('工资'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('新增账目'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮 · 已停用'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
