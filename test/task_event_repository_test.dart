import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/planner/task_event_repository.dart';

void main() {
  late AppDatabase db;
  late TaskEventRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TaskEventRepository(db);
  });
  tearDown(() => db.close());
  test('待办 CRUD、状态、日期和时间', () async {
    final id = await repo.saveTask(
      title: ' 待办 ',
      details: '说明',
      priority: 2,
      dueDate: DateTime(2026, 12, 31),
      dueTime: DateTime(2000, 1, 1, 23, 15),
    );
    var task = (await repo.watchTasks().first).single;
    expect(task.title, '待办');
    expect(task.priority, 2);
    expect(task.dueDate, '2026-12-31');
    final due = DateTime.fromMillisecondsSinceEpoch(
      task.dueAtUtc!,
      isUtc: true,
    ).toLocal();
    expect(
      [due.year, due.month, due.day, due.hour, due.minute],
      [2026, 12, 31, 23, 15],
    );
    await repo.setTaskDone(id, true);
    task = (await repo.watchTasks().first).single;
    expect(task.status, 'done');
    expect(task.completedAt, isNotNull);
    await repo.setTaskDone(id, false);
    expect((await repo.watchTasks().first).single.completedAt, isNull);
    await repo.saveTask(id: id, title: '编辑', priority: 0);
    task = (await repo.watchTasks().first).single;
    expect(task.title, '编辑');
    expect(task.dueDate, isNull);
    expect(task.dueAtUtc, isNull);
    await repo.deleteTask(id);
    expect(await repo.watchTasks().first, isEmpty);
    expect((await db.select(db.tasks).get()).single.deletedAt, isNotNull);
    await expectLater(repo.saveTask(title: ' '), throwsFormatException);
    await expectLater(
      repo.saveTask(title: 't', dueTime: DateTime.now()),
      throwsFormatException,
    );
  });
  test('日程日期、跨日、全天、编辑删除与时间校验', () async {
    final start = DateTime(2026, 12, 31, 23, 30),
        end = DateTime(2027, 1, 1, 0, 30);
    final id = await repo.saveEvent(
      title: '跨年',
      date: start,
      allDay: false,
      start: start,
      end: end,
    );
    expect(
      (await repo.watchEventsForDate(DateTime(2026, 12, 31)).first).length,
      1,
    );
    expect(
      (await repo.watchEventsForDate(DateTime(2027, 1, 1)).first).length,
      1,
    );
    final e = (await repo.watchEventsForDate(start).first).single;
    expect(e.startsAtUtc, start.toUtc().millisecondsSinceEpoch);
    expect(e.endsAtUtc, end.toUtc().millisecondsSinceEpoch);
    await repo.saveEvent(
      id: id,
      title: '全天',
      date: DateTime(2027, 1, 2),
      allDay: true,
    );
    final allDay =
        (await repo.watchEventsForDate(DateTime(2027, 1, 2)).first).single;
    expect(allDay.allDay, true);
    expect(allDay.startsAtUtc, isNull);
    expect(allDay.eventDate, '2027-01-02');
    await expectLater(
      repo.saveEvent(
        title: '错误',
        date: start,
        allDay: false,
        start: end,
        end: start,
      ),
      throwsFormatException,
    );
    await repo.deleteEvent(id);
    expect(await repo.watchEventsForDate(DateTime(2027, 1, 2)).first, isEmpty);
  });
}
