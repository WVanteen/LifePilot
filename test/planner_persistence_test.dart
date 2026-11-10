import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/planner/journal_repository.dart';
import 'package:lifepilot/features/planner/task_event_repository.dart';

void main() {
  test('V2 数据库关闭重开后保留待办、日程和日记', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lifepilot_planner_test_',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}planner.sqlite',
    );
    AppDatabase? db;
    try {
      db = AppDatabase.forTesting(NativeDatabase(file));
      final planner = TaskEventRepository(db);
      final date = DateTime(2026, 12, 31);
      await planner.saveTask(title: '持久待办', dueDate: date);
      await planner.saveEvent(title: '持久日程', date: date, allDay: true);
      await JournalRepository(db).create(date: date, content: '持久记录');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect(db.schemaVersion, 2);
      expect(
        (await TaskEventRepository(db).watchTasks().first).single.title,
        '持久待办',
      );
      expect(
        (await TaskEventRepository(
          db,
        ).watchEventsForDate(date).first).single.title,
        '持久日程',
      );
      expect(
        (await JournalRepository(db).watch(date: date).first).single.content,
        '持久记录',
      );
    } finally {
      await db?.close();
      await file.delete();
      await directory.delete();
    }
  });
}
