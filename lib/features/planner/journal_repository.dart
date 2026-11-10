import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

/// Journal dates are calendar dates, not UTC instants.
class JournalRepository {
  JournalRepository(this.db);
  final AppDatabase db;

  Stream<List<JournalEntry>> watch({DateTime? date, String? keyword}) {
    final query = db.select(db.journalEntries)
      ..where((j) {
        Expression<bool> predicate = const Constant(true);
        if (date != null) {
          predicate = predicate & j.journalDate.equals(localYmd(date));
        }
        final search = keyword?.trim();
        if (search != null && search.isNotEmpty) {
          final escaped = search
              .replaceAll(r'\', r'\\')
              .replaceAll('%', r'\%')
              .replaceAll('_', r'\_');
          predicate =
              predicate &
              (j.title.like('%$escaped%', escapeChar: r'\') |
                  j.content.like('%$escaped%', escapeChar: r'\'));
        }
        return predicate;
      })
      ..orderBy([
        (j) => OrderingTerm.desc(j.journalDate),
        (j) => OrderingTerm.desc(j.createdAt),
        (j) => OrderingTerm.desc(j.id),
      ]);
    return query.watch();
  }

  Future<String> create({
    required DateTime date,
    required String content,
    String title = '',
  }) async {
    final text = _content(content);
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.journalEntries)
        .insert(
          JournalEntriesCompanion.insert(
            id: id,
            journalDate: localYmd(date),
            content: text,
            title: Value(_title(title)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update({
    required String id,
    required DateTime date,
    required String content,
    String title = '',
  }) async {
    final text = _content(content);
    final count =
        await (db.update(
          db.journalEntries,
        )..where((j) => j.id.equals(id))).write(
          JournalEntriesCompanion(
            journalDate: Value(localYmd(date)),
            content: Value(text),
            title: Value(_title(title)),
            updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ),
        );
    if (count == 0) throw StateError('记录不存在');
  }

  /// V2 has no journal deletion marker. This permanently deletes the row.
  Future<void> delete(String id) async {
    final count = await (db.delete(
      db.journalEntries,
    )..where((j) => j.id.equals(id))).go();
    if (count == 0) throw StateError('记录不存在');
  }

  static String _content(String text) {
    final result = text.trim();
    if (result.isEmpty) throw const FormatException('记录正文不能为空');
    return result;
  }

  static String? _title(String text) =>
      text.trim().isEmpty ? null : text.trim();
}
