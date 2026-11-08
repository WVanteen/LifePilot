import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

/// Atomic operations for transfers and expense refunds. Callers must provide a
/// stable operationId for retries; repeating it never creates another record.
class TransferRefundService {
  TransferRefundService(this.db);
  final AppDatabase db;
  static final _uuid = Uuid();

  Future<String> addTransfer({
    required String operationId,
    required String accountId,
    required String targetAccountId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) => db.transaction(() async {
    _validateAmount(amountMinor);
    final existing = await _byOperation(operationId);
    if (existing != null) throw StateError('操作已提交，请勿重复提交');
    await _validateTransfer(accountId, targetAccountId);
    return _insert(
      kind: 'transfer',
      accountId: accountId,
      targetAccountId: targetAccountId,
      amountMinor: amountMinor,
      date: date,
      note: note,
      operationId: operationId,
    );
  });

  Future<String> addRefund({
    required String operationId,
    required String expenseId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) => db.transaction(() async {
    _validateAmount(amountMinor);
    final existing = await _byOperation(operationId);
    if (existing != null) throw StateError('操作已提交，请勿重复提交');
    final expense = await _validExpense(expenseId);
    await _account(expense.accountId, requireActive: true);
    await _validateRefundTotal(expense, amountMinor);
    return _insert(
      kind: 'refund',
      accountId: expense.accountId,
      categoryId: expense.categoryId,
      refundOfId: expense.id,
      amountMinor: amountMinor,
      date: date,
      note: note,
      operationId: operationId,
    );
  });

  Future<void> editTransfer({
    required String id,
    required String accountId,
    required String targetAccountId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) => db.transaction(() async {
    _validateAmount(amountMinor);
    final old = await _entry(id, 'transfer', deleted: false);
    await _validateTransfer(
      accountId,
      targetAccountId,
      sourceMayBeInactive: accountId == old.accountId,
      targetMayBeInactive: targetAccountId == old.targetAccountId,
    );
    await _write(
      id,
      LedgerTransactionsCompanion(
        accountId: Value(accountId),
        targetAccountId: Value(targetAccountId),
        amountMinor: Value(amountMinor),
        localDate: Value(localYmd(date)),
        note: Value(_note(note)),
        updatedAt: Value(_now()),
      ),
    );
  });

  Future<void> editRefund({
    required String id,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) => db.transaction(() async {
    _validateAmount(amountMinor);
    final old = await _entry(id, 'refund', deleted: false);
    final expense = await _validExpense(old.refundOfId ?? '');
    await _account(expense.accountId, requireActive: false);
    await _validateRefundTotal(expense, amountMinor, excludeId: id);
    await _write(
      id,
      LedgerTransactionsCompanion(
        amountMinor: Value(amountMinor),
        localDate: Value(localYmd(date)),
        note: Value(_note(note)),
        updatedAt: Value(_now()),
      ),
    );
  });

  Future<void> delete(String id) => db.transaction(() async {
    final entry = await _anyExtendedEntry(id, deleted: false);
    await _write(
      entry.id,
      LedgerTransactionsCompanion(
        deletedAt: Value(_now()),
        updatedAt: Value(_now()),
      ),
    );
  });

  Future<void> restore(String id) => db.transaction(() async {
    final entry = await _anyExtendedEntry(id, deleted: true);
    if (entry.kind == 'refund') {
      final expense = await _validExpense(entry.refundOfId ?? '');
      if (entry.accountId != expense.accountId ||
          entry.currency != expense.currency ||
          entry.categoryId != expense.categoryId) {
        throw StateError('原支出已变更，无法恢复退款');
      }
      await _account(entry.accountId, requireActive: false);
      await _validateRefundTotal(expense, entry.amountMinor);
    } else {
      await _validateTransfer(
        entry.accountId,
        entry.targetAccountId ?? '',
        sourceMayBeInactive: true,
        targetMayBeInactive: true,
      );
    }
    await _write(
      id,
      LedgerTransactionsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_now()),
      ),
    );
  });

  Future<void> _validateTransfer(
    String from,
    String to, {
    bool sourceMayBeInactive = false,
    bool targetMayBeInactive = false,
  }) async {
    if (from == to) throw const FormatException('转出和转入账户不能相同');
    final a = await _account(from, requireActive: !sourceMayBeInactive);
    final b = await _account(to, requireActive: !targetMayBeInactive);
    if (a.currency != b.currency || a.currency != 'CNY') {
      throw const FormatException('当前仅支持人民币账户之间转账');
    }
  }

  Future<Account> _account(String id, {required bool requireActive}) async {
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (account == null || (requireActive && !account.isActive)) {
      throw const FormatException('账户不存在或已停用');
    }
    if (account.currency != 'CNY') throw const FormatException('当前仅支持人民币账户');
    return account;
  }

  Future<LedgerTransaction> _validExpense(String id) async {
    final expense = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (expense == null ||
        expense.kind != 'expense' ||
        expense.deletedAt != null ||
        expense.categoryId == null ||
        expense.currency != 'CNY') {
      throw const FormatException('原支出不存在、已删除或无效');
    }
    return expense;
  }

  Future<void> _validateRefundTotal(
    LedgerTransaction expense,
    int amount, {
    String? excludeId,
  }) async {
    final refunds =
        await (db.select(db.ledgerTransactions)..where(
              (t) =>
                  t.refundOfId.equals(expense.id) &
                  t.kind.equals('refund') &
                  t.deletedAt.isNull(),
            ))
            .get();
    final already = refunds
        .where((r) => r.id != excludeId)
        .fold<int>(0, (sum, r) => sum + r.amountMinor);
    if (amount + already > expense.amountMinor) {
      throw const FormatException('退款总额不能超过原支出');
    }
  }

  Future<LedgerTransaction?> _byOperation(String id) {
    if (id.trim().isEmpty) throw const FormatException('操作标识不能为空');
    return (db.select(
      db.ledgerTransactions,
    )..where((t) => t.sourceDraftId.equals(id))).getSingleOrNull();
  }

  Future<LedgerTransaction> _entry(
    String id,
    String kind, {
    required bool deleted,
  }) async {
    final entry = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null ||
        entry.kind != kind ||
        (entry.deletedAt != null) != deleted) {
      throw StateError('记录不存在或状态已改变');
    }
    return entry;
  }

  Future<LedgerTransaction> _anyExtendedEntry(
    String id, {
    required bool deleted,
  }) async {
    final entry = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null ||
        !{'transfer', 'refund'}.contains(entry.kind) ||
        (entry.deletedAt != null) != deleted) {
      throw StateError('记录不存在或状态已改变');
    }
    return entry;
  }

  Future<String> _insert({
    required String kind,
    required String accountId,
    String? targetAccountId,
    String? categoryId,
    String? refundOfId,
    required int amountMinor,
    required DateTime date,
    required String note,
    required String operationId,
  }) async {
    final id = _uuid.v4();
    final now = _now();
    await db
        .into(db.ledgerTransactions)
        .insert(
          LedgerTransactionsCompanion.insert(
            id: id,
            kind: kind,
            amountMinor: amountMinor,
            accountId: accountId,
            targetAccountId: Value(targetAccountId),
            categoryId: Value(categoryId),
            refundOfId: Value(refundOfId),
            localDate: localYmd(date),
            note: Value(_note(note)),
            sourceDraftId: Value(operationId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> _write(String id, LedgerTransactionsCompanion changes) async {
    await (db.update(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).write(changes);
  }

  static void _validateAmount(int amount) {
    if (amount <= 0 || amount > 100000000000) {
      throw const FormatException('金额必须大于零且在允许范围内');
    }
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;
  static String? _note(String note) => note.trim().isEmpty ? null : note.trim();
}
