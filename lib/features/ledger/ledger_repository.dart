import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import 'transfer_refund_service.dart';

class LedgerRepository {
  LedgerRepository(this.db);
  final AppDatabase db;
  static final _uuid = Uuid();

  Stream<List<LedgerTransaction>> watchEntries({
    String? kind,
    String? categoryId,
    String? accountId,
    String? keyword,
    DateTime? fromDate,
    DateTime? toDate,
    bool deleted = false,
    bool sortByAmount = false,
    bool ascending = false,
  }) {
    final query = db.select(db.ledgerTransactions)
      ..where((t) {
        var predicate = deleted
            ? t.deletedAt.isNotNull()
            : t.deletedAt.isNull();
        if (kind != null) predicate = predicate & t.kind.equals(kind);
        if (categoryId != null) {
          predicate = predicate & t.categoryId.equals(categoryId);
        }
        if (accountId != null) {
          predicate =
              predicate &
              (t.accountId.equals(accountId) |
                  t.targetAccountId.equals(accountId));
        }
        final search = keyword?.trim();
        if (search != null && search.isNotEmpty) {
          final escaped = search
              .replaceAll(r'\', r'\\')
              .replaceAll('%', r'\%')
              .replaceAll('_', r'\_');
          predicate =
              predicate &
              (t.merchant.like('%$escaped%', escapeChar: r'\') |
                  t.note.like('%$escaped%', escapeChar: r'\'));
        }
        if (fromDate != null) {
          predicate =
              predicate & t.localDate.isBiggerOrEqualValue(localYmd(fromDate));
        }
        if (toDate != null) {
          predicate =
              predicate & t.localDate.isSmallerOrEqualValue(localYmd(toDate));
        }
        return predicate;
      })
      ..orderBy([
        (t) => OrderingTerm(
          expression: sortByAmount ? t.amountMinor : t.localDate,
          mode: ascending ? OrderingMode.asc : OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<List<Category>> watchCategories() {
    final query = db.select(db.categories)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return query.watch();
  }

  Stream<List<Account>> watchAccounts() {
    final query = db.select(db.accounts)
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);
    return query.watch();
  }

  Stream<LedgerSummary> watchMonthSummary(DateTime month) {
    final (start, end) = _monthBounds(month);
    final query = db.select(db.ledgerTransactions)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.localDate.isBiggerOrEqualValue(start) &
            t.localDate.isSmallerThanValue(end),
      );
    return query.watch().map(LedgerSummary.fromTransactions);
  }

  Stream<List<CategoryExpenseTotal>> watchMonthExpenseByCategory(
    DateTime month,
  ) {
    final (start, end) = _monthBounds(month);
    final query =
        db.select(db.ledgerTransactions).join([
          innerJoin(
            db.categories,
            db.categories.id.equalsExp(db.ledgerTransactions.categoryId),
          ),
        ])..where(
          db.ledgerTransactions.deletedAt.isNull() &
              (db.ledgerTransactions.kind.equals('expense') |
                  db.ledgerTransactions.kind.equals('refund')) &
              db.ledgerTransactions.localDate.isBiggerOrEqualValue(start) &
              db.ledgerTransactions.localDate.isSmallerThanValue(end),
        );
    return query.watch().map((rows) {
      final totals = <String, CategoryExpenseTotal>{};
      for (final row in rows) {
        final transaction = row.readTable(db.ledgerTransactions);
        final category = row.readTable(db.categories);
        final previous = totals[category.id];
        totals[category.id] = CategoryExpenseTotal(
          categoryId: category.id,
          categoryName: category.name,
          amountMinor:
              (previous?.amountMinor ?? 0) +
              (transaction.kind == 'refund'
                  ? -transaction.amountMinor
                  : transaction.amountMinor),
        );
      }
      final result = totals.values.toList()
        ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
      return result;
    });
  }

  Future<String> addManual({
    required String kind,
    required String amount,
    required String categoryId,
    String accountId = 'acc_cash',
    DateTime? transactionDate,
    String note = '',
    String merchant = '',
  }) async {
    final amountMinor = parseCnyMinor(amount);
    final now = DateTime.now();
    final ts = now.toUtc().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.transaction(() async {
      await _validateReferences(
        kind: kind,
        categoryId: categoryId,
        accountId: accountId,
      );
      await db
          .into(db.ledgerTransactions)
          .insert(
            LedgerTransactionsCompanion.insert(
              id: id,
              kind: kind,
              amountMinor: amountMinor,
              accountId: accountId,
              categoryId: Value(categoryId),
              localDate: localYmd(transactionDate ?? now),
              note: Value(_nullableTrimmed(note)),
              merchant: Value(_nullableTrimmed(merchant)),
              createdAt: ts,
              updatedAt: ts,
            ),
          );
    });
    return id;
  }

  Future<void> updateManual({
    required String id,
    required String kind,
    required String amount,
    required String categoryId,
    required String accountId,
    required DateTime transactionDate,
    String note = '',
    String merchant = '',
  }) async {
    final amountMinor = parseCnyMinor(amount);
    await db.transaction(() async {
      final existing =
          await (db.select(db.ledgerTransactions)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) throw StateError('账目不存在或已删除');
      final refunds =
          await (db.select(db.ledgerTransactions)..where(
                (t) =>
                    t.refundOfId.equals(id) &
                    t.kind.equals('refund') &
                    t.deletedAt.isNull(),
              ))
              .get();
      final refunded = refunds.fold<int>(
        0,
        (sum, row) => sum + row.amountMinor,
      );
      if (refunds.isNotEmpty &&
          (kind != 'expense' ||
              accountId != existing.accountId ||
              categoryId != existing.categoryId ||
              amountMinor < refunded)) {
        throw StateError('存在关联退款，不能更改账户、分类、类型或将金额降至退款总额以下');
      }
      await _validateReferences(
        kind: kind,
        categoryId: categoryId,
        accountId: accountId,
        allowInactiveAccount: existing.accountId == accountId,
        allowInactiveCategory:
            existing.categoryId == categoryId && existing.kind == kind,
      );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (db.update(
        db.ledgerTransactions,
      )..where((t) => t.id.equals(id))).write(
        LedgerTransactionsCompanion(
          kind: Value(kind),
          amountMinor: Value(amountMinor),
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          localDate: Value(localYmd(transactionDate)),
          note: Value(_nullableTrimmed(note)),
          merchant: Value(_nullableTrimmed(merchant)),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> softDelete(String id) async {
    final entry = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry != null && (entry.kind == 'transfer' || entry.kind == 'refund')) {
      return TransferRefundService(db).delete(id);
    }
    await db.transaction(() async {
      final refunds =
          await (db.select(db.ledgerTransactions)..where(
                (t) =>
                    t.refundOfId.equals(id) &
                    t.kind.equals('refund') &
                    t.deletedAt.isNull(),
              ))
              .get();
      if (refunds.isNotEmpty) throw StateError('存在关联退款，请先删除退款');
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await (db.update(
        db.ledgerTransactions,
      )..where((t) => t.id.equals(id))).write(
        LedgerTransactionsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> restore(String id) async {
    final entry = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry != null && (entry.kind == 'transfer' || entry.kind == 'refund')) {
      return TransferRefundService(db).restore(id);
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (db.update(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).write(
      LedgerTransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _validateReferences({
    required String kind,
    required String categoryId,
    required String accountId,
    bool allowInactiveAccount = false,
    bool allowInactiveCategory = false,
  }) async {
    if (kind != 'expense' && kind != 'income') {
      throw const FormatException('手动记账仅支持收入和支出');
    }
    final category = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (category == null || category.type != kind) {
      throw const FormatException('账目分类与收支类型不匹配');
    }
    if (!category.isActive && !allowInactiveCategory) {
      throw const FormatException('所选分类已停用');
    }
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) throw const FormatException('所选账户不存在');
    if (!account.isActive && !allowInactiveAccount) {
      throw const FormatException('所选账户已停用');
    }
    if (account.currency != 'CNY') {
      throw const FormatException('当前版本仅支持人民币账户');
    }
  }

  static (String, String) _monthBounds(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (localYmd(start), localYmd(end));
  }

  static String? _nullableTrimmed(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class LedgerSummary {
  const LedgerSummary({required this.incomeMinor, required this.expenseMinor});

  factory LedgerSummary.fromTransactions(List<LedgerTransaction> rows) {
    var income = 0;
    var expense = 0;
    for (final row in rows) {
      if (row.kind == 'income') income += row.amountMinor;
      if (row.kind == 'expense') expense += row.amountMinor;
      if (row.kind == 'refund') expense -= row.amountMinor;
    }
    return LedgerSummary(incomeMinor: income, expenseMinor: expense);
  }

  final int incomeMinor;
  final int expenseMinor;
  int get balanceMinor => incomeMinor - expenseMinor;
}

class CategoryExpenseTotal {
  const CategoryExpenseTotal({
    required this.categoryId,
    required this.categoryName,
    required this.amountMinor,
  });

  final String categoryId;
  final String categoryName;
  final int amountMinor;
}
