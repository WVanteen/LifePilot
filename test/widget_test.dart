import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/app/lifepilot_app.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';

void main() {
  testWidgets('all main navigation destinations are visible', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const LifePilotApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('LifePilot  ·  '), findsNothing);
    await tester.tap(find.text('记账').last);
    await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('本月分类支出'), findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    expect(find.text('新增账目'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.textContaining('交易日期：'), findsOneWidget);
    Navigator.of(tester.element(find.text('新增账目'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').last);
    await tester.pumpAndSettle();
    expect(find.text('聪明的生活管家，即将上线'), findsOneWidget);

    // Disposing StreamProviders schedules Drift stream cleanup on the next
    // event-loop turn. Unmount and pump it before the test binding checks for
    // pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
