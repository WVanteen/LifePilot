import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

class LedgerRepository {
  LedgerRepository(this.db);
  final AppDatabase db;
  static final _uuid = Uuid();

  Stream<List<LedgerTransaction>> watchEntries() {
    final query = db.select(db.ledgerTransactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy((t) => [
            OrderingTerm(expression: t.localDate, mode: OrderingMode.desc),
            OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]);
    return query.watch();
  }

  Stream<List<Category>> watchCategories() {
    final query = db.select(db.categories)
      ..orderBy((t) => [OrderingTerm(expression: t.sortOrder)]);
    return query.watch();
  }

  Future<String> addManual({
    required String kind,
    required String amount,
    required String categoryId,
    String note = '',
  }) async {
    if (kind != 'expense' && kind != 'income') {
      throw const FormatException('第一周仅支持收入和支出');
    }
    final amountMinor = parseCnyMinor(amount);
    final category = await (db.select(db.categories)
          ..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
    if (category == null || category.type != kind) {
      throw const FormatException('账目分类与收支类型不匹配');
    }
    final now = DateTime.now();
    final ts = now.toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.into(db.ledgerTransactions).insert(
          LedgerTransactionsCompanion.insert(
            id: id,
            kind: kind,
            amountMinor: amountMinor,
            accountId: 'acc_cash',
            categoryId: Value(categoryId),
            localDate: localYmd(now),
            note: Value(note.trim().isEmpty ? null : note.trim()),
            createdAt: ts,
            updatedAt: ts,
          ),
        );
    return id;
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (db.update(db.ledgerTransactions)
          ..where((t) => t.id.equals(id)))
        .write(LedgerTransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
  }
}
