import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

class AccountRepository {
  AccountRepository(this.db);
  final AppDatabase db;
  static const defaultKey = 'default_account_id';
  static const accountTypes = {'cash', 'bank', 'alipay', 'wechat', 'other'};

  Stream<List<Account>> watchAccounts({bool activeOnly = false}) {
    final query = db.select(db.accounts)
      ..where(
        (a) => activeOnly ? a.isActive.equals(true) : const Constant(true),
      )
      ..orderBy([
        (a) => OrderingTerm(expression: a.createdAt),
        (a) => OrderingTerm(expression: a.id),
      ]);
    return query.watch();
  }

  Future<List<Account>> getAccounts({bool activeOnly = false}) =>
      watchAccounts(activeOnly: activeOnly).first;

  Future<Account?> getById(String id) =>
      (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    required String accountType,
    required String currency,
    required int openingBalanceMinor,
    bool makeDefault = false,
  }) async {
    final cleanName = _validate(name, accountType);
    final cleanCurrency = currency.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw const FormatException('请输入有效的三位币种代码');
    }
    final id = const Uuid().v4();
    await db.transaction(() async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              name: cleanName,
              accountType: Value(accountType),
              currency: Value(cleanCurrency),
              openingBalanceMinor: Value(openingBalanceMinor),
              createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );
      if (makeDefault) {
        await _saveDefault(id);
      } else {
        await _resolveDefault();
      }
    });
    return id;
  }

  Future<void> update({
    required String id,
    required String name,
    required String accountType,
    required int openingBalanceMinor,
    bool makeDefault = false,
  }) async {
    final cleanName = _validate(name, accountType);
    await db.transaction(() async {
      final count =
          await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
            AccountsCompanion(
              name: Value(cleanName),
              accountType: Value(accountType),
              openingBalanceMinor: Value(openingBalanceMinor),
            ),
          );
      if (count == 0) throw StateError('账户不存在');
      if (makeDefault) {
        final account = await getById(id);
        if (account == null || !account.isActive) {
          throw StateError('默认账户必须是启用账户');
        }
        await _saveDefault(id);
      }
    });
  }

  Future<Account?> getDefault() => db.transaction(_resolveDefault);

  Future<void> setDefault(String id) => db.transaction(() async {
    final account = await getById(id);
    if (account == null || !account.isActive) throw StateError('默认账户必须是启用账户');
    await _saveDefault(id);
  });

  Future<void> deactivate(String id) => db.transaction(() async {
    final account = await getById(id);
    if (account == null) throw StateError('账户不存在');
    if (!account.isActive) return;
    final active = await (db.select(
      db.accounts,
    )..where((a) => a.isActive.equals(true))).get();
    if (active.length <= 1) throw StateError('不能停用最后一个启用账户');
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(
      const AccountsCompanion(isActive: Value(false)),
    );
    await _resolveDefault();
  });

  Future<void> restore(String id) async {
    final count = await (db.update(db.accounts)..where((a) => a.id.equals(id)))
        .write(const AccountsCompanion(isActive: Value(true)));
    if (count == 0) throw StateError('账户不存在');
  }

  Stream<int> watchBalance(String accountId) {
    return db
        .customSelect(
          '''
      SELECT a.opening_balance_minor AS opening, a.currency AS currency,
        COALESCE(SUM(CASE WHEN t.currency = a.currency AND t.kind = 'income' THEN t.amount_minor
          WHEN t.currency = a.currency AND t.kind = 'expense' THEN -t.amount_minor ELSE 0 END), 0) AS movement,
        COALESCE(SUM(CASE WHEN t.currency != a.currency THEN 1 ELSE 0 END), 0) AS mismatches
      FROM accounts a LEFT JOIN ledger_transactions t ON t.account_id = a.id
        AND t.deleted_at IS NULL AND t.kind IN ('income', 'expense')
      WHERE a.id = ? GROUP BY a.id
    ''',
          variables: [Variable.withString(accountId)],
          readsFrom: {db.accounts, db.ledgerTransactions},
        )
        .watch()
        .map((rows) {
          if (rows.isEmpty) throw StateError('账户不存在');
          final row = rows.single;
          if (row.read<int>('mismatches') != 0) throw StateError('账户包含不同币种的交易');
          return row.read<int>('opening') + row.read<int>('movement');
        });
  }

  Future<int> getBalance(String id) => watchBalance(id).first;

  Future<Account?> _resolveDefault() async {
    final setting = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(defaultKey))).getSingleOrNull();
    if (setting != null) {
      final selected = await getById(setting.value);
      if (selected != null && selected.isActive) return selected;
    }
    final active =
        await (db.select(db.accounts)
              ..where((a) => a.isActive.equals(true))
              ..orderBy([
                (a) => OrderingTerm(expression: a.createdAt),
                (a) => OrderingTerm(expression: a.id),
              ]))
            .get();
    if (active.isEmpty) return null;
    final preferred = active.where((a) => a.id == 'acc_cash');
    final selected = preferred.isEmpty ? active.first : preferred.first;
    await _saveDefault(selected.id);
    return selected;
  }

  Future<void> _saveDefault(String id) async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: defaultKey, value: id),
        );
  }

  static String _validate(String name, String type) {
    final clean = name.trim();
    if (clean.isEmpty) throw const FormatException('账户名称不能为空');
    if (!accountTypes.contains(type)) throw const FormatException('无效的账户类型');
    return clean;
  }
}
