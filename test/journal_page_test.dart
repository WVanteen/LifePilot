import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/planner/journal_page.dart';
import 'package:lifepilot/features/planner/journal_repository.dart';

void main() {
  testWidgets('日记按所选日期展示、搜索并确认删除', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = JournalRepository(db);
    final today = DateTime(2026, 4, 3);
    await repo.create(date: today, title: '测试标题', content: '今天写了日记');
    await repo.create(date: DateTime(2026, 4, 2), content: '之前的记录');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalSection(repository: repo, selectedDate: today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('测试标题'), findsOneWidget);
    expect(find.text('之前的记录'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '找不到');
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的记录'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '日记');
    await tester.pumpAndSettle();
    expect(find.text('今天写了日记'), findsOneWidget);
    await tester.tap(find.byTooltip('记录操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('删除后无法恢复'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('今天写了日记'), findsOneWidget);
    await tester.tap(find.byTooltip('记录操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的记录'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
