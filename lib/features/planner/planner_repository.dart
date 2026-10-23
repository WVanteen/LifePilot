import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

class PlannerRepository {
  PlannerRepository(this.db);
  final AppDatabase db;
  static final _uuid = Uuid();

  Stream<List<Task>> watchTasks() {
    final query = db.select(db.tasks)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<List<JournalEntry>> watchJournal() {
    final query = db.select(db.journalEntries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Future<String> addTask(String title, {DateTime? dueDate}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw const FormatException('待办名称不能为空');
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.into(db.tasks).insert(TasksCompanion.insert(
      id: id,
      title: trimmed,
      dueDate: Value(dueDate == null ? null : localYmd(dueDate)),
      createdAt: ts,
      updatedAt: ts,
    ));
    return id;
  }

  Future<void> toggleTask(Task task) async {
    final isDone = task.status == 'done';
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (db.update(db.tasks)..where((t) => t.id.equals(task.id)))
        .write(TasksCompanion(
          status: Value(isDone ? 'todo' : 'done'),
          completedAt: Value(isDone ? null : ts),
          updatedAt: Value(ts),
        ));
  }

  Future<String> addJournal(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw const FormatException('日记内容不能为空');
    final now = DateTime.now();
    final ts = now.toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
      id: id,
      journalDate: localYmd(now),
      content: trimmed,
      createdAt: ts,
      updatedAt: ts,
    ));
    return id;
  }
}
