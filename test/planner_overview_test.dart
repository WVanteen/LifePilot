import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/core/utils/money.dart';
import 'package:lifepilot/features/planner/planner_page.dart';
import 'package:lifepilot/features/planner/planner_repository.dart';

void main() {
  testWidgets('当天概览按日期聚合待办、日程和日记', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    final repo = PlannerRepository(db);
    await repo.addTask('当天任务', dueDate: DateTime.now());
    await repo.addTask(
      '明天任务',
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );
    await repo.addJournal('当天记录正文');
    final now = DateTime.now();
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'event-today',
            title: '当天日程',
            eventDate: localYmd(now),
            allDay: const Value(true),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: PlannerPage())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看当天概览'));
    await tester.pumpAndSettle();
    expect(find.textContaining('当天概览'), findsWidgets);
    expect(find.text('当天任务'), findsWidgets);
    expect(find.text('当天日程'), findsWidgets);
    expect(find.text('当天记录正文'), findsOneWidget);
    final overview = find.byType(BottomSheet);
    expect(
      find.descendant(of: overview, matching: find.text('明天任务')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
