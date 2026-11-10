import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';

final taskEventRepositoryProvider = Provider<TaskEventRepository>(
  (ref) => TaskEventRepository(ref.watch(appDatabaseProvider)),
);

class TaskEventRepository {
  TaskEventRepository(this.db);
  final AppDatabase db;

  Stream<List<Task>> watchTasks() =>
      (db.select(db.tasks)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Stream<List<Event>> watchEventsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);
    return db.select(db.events).watch().map((events) {
      final rows = events.where((event) {
        if (event.allDay) return event.eventDate == localYmd(start);
        if (event.startsAtUtc == null || event.endsAtUtc == null) {
          return event.eventDate == localYmd(start);
        }
        final eventStart = DateTime.fromMillisecondsSinceEpoch(
          event.startsAtUtc!,
          isUtc: true,
        );
        final eventEnd = DateTime.fromMillisecondsSinceEpoch(
          event.endsAtUtc!,
          isUtc: true,
        );
        return eventStart.isBefore(end.toUtc()) &&
            (eventEnd.isAfter(start.toUtc()) ||
                eventEnd.isAtSameMomentAs(eventStart) &&
                    !eventStart.isBefore(start.toUtc()));
      }).toList();
      rows.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return (a.startsAtUtc ?? 0).compareTo(b.startsAtUtc ?? 0);
      });
      return rows;
    });
  }

  Future<String> saveTask({
    String? id,
    required String title,
    String details = '',
    int priority = 1,
    DateTime? dueDate,
    DateTime? dueTime,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) throw const FormatException('待办标题不能为空');
    if (priority < 0 || priority > 2) throw const FormatException('优先级无效');
    if (dueTime != null && dueDate == null) {
      throw const FormatException('设置时间前请选择日期');
    }
    final localDate = dueDate == null
        ? null
        : DateTime(dueDate.year, dueDate.month, dueDate.day);
    final instant = dueTime == null
        ? null
        : DateTime(
            localDate!.year,
            localDate.month,
            localDate.day,
            dueTime.hour,
            dueTime.minute,
          ).toUtc().millisecondsSinceEpoch;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final taskId = id ?? const Uuid().v4();
    if (id == null) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: taskId,
              title: clean,
              details: Value(details.trim().isEmpty ? null : details.trim()),
              priority: Value(priority),
              dueDate: Value(localDate == null ? null : localYmd(localDate)),
              dueAtUtc: Value(instant),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      final count =
          await (db.update(
            db.tasks,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            TasksCompanion(
              title: Value(clean),
              details: Value(details.trim().isEmpty ? null : details.trim()),
              priority: Value(priority),
              dueDate: Value(localDate == null ? null : localYmd(localDate)),
              dueAtUtc: Value(instant),
              updatedAt: Value(now),
            ),
          );
      if (count == 0) throw StateError('待办不存在或已删除');
    }
    return taskId;
  }

  Future<void> setTaskDone(String id, bool done) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final count =
        await (db.update(
          db.tasks,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          TasksCompanion(
            status: Value(done ? 'done' : 'todo'),
            completedAt: Value(done ? now : null),
            updatedAt: Value(now),
          ),
        );
    if (count == 0) throw StateError('待办不存在或已删除');
  }

  Future<void> deleteTask(String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final count =
        await (db.update(
          db.tasks,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          TasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    if (count == 0) throw StateError('待办不存在或已删除');
  }

  Future<String> saveEvent({
    String? id,
    required String title,
    String description = '',
    required DateTime date,
    required bool allDay,
    DateTime? start,
    DateTime? end,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) throw const FormatException('日程标题不能为空');
    if (!allDay && (start == null || end == null)) {
      throw const FormatException('请选择开始和结束时间');
    }
    if (!allDay && end!.isBefore(start!)) {
      throw const FormatException('结束时间不能早于开始时间');
    }
    final localStart = allDay ? null : start!.toLocal();
    final dateValue = allDay ? localYmd(date) : localYmd(localStart!);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final eventId = id ?? const Uuid().v4();
    if (id == null) {
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              id: eventId,
              title: clean,
              description: Value(
                description.trim().isEmpty ? null : description.trim(),
              ),
              eventDate: dateValue,
              allDay: Value(allDay),
              startsAtUtc: Value(localStart?.toUtc().millisecondsSinceEpoch),
              endsAtUtc: Value(
                allDay ? null : end!.toUtc().millisecondsSinceEpoch,
              ),
              timezone: const Value('local'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      final count = await (db.update(db.events)..where((e) => e.id.equals(id)))
          .write(
            EventsCompanion(
              title: Value(clean),
              description: Value(
                description.trim().isEmpty ? null : description.trim(),
              ),
              eventDate: Value(dateValue),
              allDay: Value(allDay),
              startsAtUtc: Value(localStart?.toUtc().millisecondsSinceEpoch),
              endsAtUtc: Value(
                allDay ? null : end!.toUtc().millisecondsSinceEpoch,
              ),
              timezone: const Value('local'),
              updatedAt: Value(now),
            ),
          );
      if (count == 0) throw StateError('日程不存在');
    }
    return eventId;
  }

  Future<void> deleteEvent(String id) async {
    final count = await (db.delete(
      db.events,
    )..where((e) => e.id.equals(id))).go();
    if (count == 0) throw StateError('日程不存在');
  }
}
