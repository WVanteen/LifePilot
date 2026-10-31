import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/app/lifepilot_app.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/accounts/account_repository.dart';

void main() {
  testWidgets('create default account and show error when deactivating last active account', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final repo = AccountRepository(db);
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const LifePilotApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('账户管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('不能停用最后一个启用账户'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '账户名称'), '新账户');
    await tester.tap(find.text('设为默认账户'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect((await repo.getDefault())!.name, '新账户');
    expect(find.text('新账户'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets(
    'edit, set default, cancel and confirm deactivation, then restore',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.seedDefaults();
      final repo = AccountRepository(db);
      final id = await repo.create(
        name: '测试账户',
        accountType: 'cash',
        currency: 'CNY',
        openingBalanceMinor: 100,
      );
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const LifePilotApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('账户管理'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '账户名称'),
        '修改账户',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '初始余额'),
        '12.34',
      );
      await tester.tap(find.text('现金').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('银行卡').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('设为默认账户'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect((await repo.getById(id))!.name, '修改账户');
      expect((await repo.getById(id))!.accountType, 'bank');
      expect((await repo.getById(id))!.openingBalanceMinor, 1234);
      expect((await repo.getDefault())!.id, id);
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();
      expect(find.text('停用账户？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect((await repo.getById(id))!.isActive, isTrue);
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();
      expect((await repo.getById(id))!.isActive, isFalse);
      await tester.tap(find.textContaining('已停用账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复').last);
      await tester.pumpAndSettle();
      expect((await repo.getById(id))!.isActive, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  testWidgets('account list, default, balance and add form validation', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LifePilotApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('账户管理'));
    await tester.pumpAndSettle();
    expect(find.text('现金'), findsWidgets);
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('¥0.00'), findsWidgets);
    await tester.tap(find.text('添加账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入账户名称'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
