import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

/// Totals are in integer minor units; refunds reduce expenditure on their date.
class LedgerTotals {
  const LedgerTotals({this.income = 0, this.expense = 0});
  final int income;
  final int expense;
  int get balance => income - expense;
  LedgerTotals add(String kind, int amount) => switch (kind) {
    'income' => LedgerTotals(income: income + amount, expense: expense),
    'expense' => LedgerTotals(income: income, expense: expense + amount),
    'refund' => LedgerTotals(income: income, expense: expense - amount),
    _ => this,
  };
}

class LedgerStatistics {
  const LedgerStatistics({
    required this.total,
    required this.categories,
    required this.accounts,
    required this.daily,
  });
  final LedgerTotals total;
  final Map<String, LedgerTotals> categories;
  final Map<String, LedgerTotals> accounts;
  final Map<String, LedgerTotals> daily;
}

/// Uses the original expense category for refunds, including cross-period refunds.
class LedgerStatisticsService {
  LedgerStatisticsService(this.db);
  final AppDatabase db;

  Stream<LedgerStatistics> watch(
    DateTime start,
    DateTime endExclusive, {
    String currency = 'CNY',
  }) {
    if (!endExclusive.isAfter(start)) {
      throw ArgumentError('Invalid statistics period');
    }
    final original = db.alias(db.ledgerTransactions, 'original_expense');
    final transaction = db.ledgerTransactions;
    final query =
        db.select(transaction).join([
          leftOuterJoin(
            original,
            original.id.equalsExp(transaction.refundOfId),
          ),
        ])..where(
          transaction.deletedAt.isNull() &
              transaction.currency.equals(currency) &
              transaction.localDate.isBiggerOrEqualValue(localYmd(start)) &
              transaction.localDate.isSmallerThanValue(localYmd(endExclusive)),
        );
    return query.watch().map((rows) {
      var total = const LedgerTotals();
      final categories = <String, LedgerTotals>{};
      final accounts = <String, LedgerTotals>{};
      final daily = <String, LedgerTotals>{};
      for (final row in rows) {
        final entry = row.readTable(transaction);
        if (entry.kind != 'income' &&
            entry.kind != 'expense' &&
            entry.kind != 'refund') {
          continue;
        }
        final source = row.readTableOrNull(original);
        // Invalid orphan refunds are not silently attributed to an arbitrary category.
        if (entry.kind == 'refund' &&
            (source == null ||
                source.kind != 'expense' ||
                source.deletedAt != null ||
                source.currency != entry.currency)) {
          continue;
        }
        total = total.add(entry.kind, entry.amountMinor);
        void accumulate(Map<String, LedgerTotals> map, String key) {
          map[key] = (map[key] ?? const LedgerTotals()).add(
            entry.kind,
            entry.amountMinor,
          );
        }

        accumulate(accounts, entry.accountId);
        accumulate(daily, entry.localDate);
        final category = entry.kind == 'refund'
            ? source?.categoryId
            : entry.categoryId;
        if (category != null) accumulate(categories, category);
      }
      return LedgerStatistics(
        total: total,
        categories: categories,
        accounts: accounts,
        daily: Map.fromEntries(
          daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
      );
    });
  }
}
