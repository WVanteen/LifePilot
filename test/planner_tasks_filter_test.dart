import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/core/providers.dart';
import 'package:lifepilot/features/planner/task_event_pages.dart';
import 'package:lifepilot/features/planner/task_event_repository.dart';

void main() {
  testWidgets('按状态及无截止日期筛选并按优先级排序', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = TaskEventRepository(db);
    await repo.saveTask(title: '低优先级', priority: 0);
    await repo.saveTask(title: '高优先级', priority: 2);
    final done = await repo.saveTask(title: '已完成任务', dueDate: DateTime.now());
    await repo.setTaskDone(done, true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: PlannerTasksTab())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('无截止日期').last);
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    await tester.tap(find.text('按截止日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按优先级').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('高优先级')).dy,
      lessThan(tester.getTopLeft(find.text('低优先级')).dy),
    );
    await tester.tap(find.text('全部状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无符合条件的待办'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
