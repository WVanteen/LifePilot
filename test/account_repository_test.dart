import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/accounts/account_repository.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late LedgerRepository ledger;
  var closed = false;
  setUp(() async {
    closed = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    accounts = AccountRepository(db);
    ledger = LedgerRepository(db);
  });
  tearDown(() async {
    if (!closed) await db.close();
  });

  test(
    'save and default selection roll back together on database failure',
    () async {
      final id = await accounts.create(
        name: '旧名称',
        accountType: 'bank',
        currency: 'CNY',
        openingBalanceMinor: 100,
      );
      await accounts.getDefault();
      await db.customStatement(
        "CREATE TRIGGER fail_default BEFORE UPDATE ON app_settings BEGIN SELECT RAISE(ABORT, 'default failed'); END",
      );
      await expectLater(
        accounts.update(
          id: id,
          name: '新名称',
          accountType: 'wechat',
          openingBalanceMinor: 200,
          makeDefault: true,
        ),
        throwsA(anything),
      );
      expect((await accounts.getById(id))!.name, '旧名称');
      expect((await accounts.getById(id))!.openingBalanceMinor, 100);
      await expectLater(
        accounts.create(
          name: '新账户',
          accountType: 'cash',
          currency: 'CNY',
          openingBalanceMinor: 0,
          makeDefault: true,
        ),
        throwsA(anything),
      );
      expect((await accounts.getAccounts()).length, 2);
      expect((await accounts.getDefault())!.id, 'acc_cash');
    },
  );

  test('create, edit and validate account and opening balance', () async {
    final id = await accounts.create(
      name: ' 银行卡 ',
      accountType: 'bank',
      currency: 'CNY',
      openingBalanceMinor: 12345,
    );
    expect((await accounts.getById(id))!.name, '银行卡');
    expect(await accounts.getBalance(id), 12345);
    await accounts.update(
      id: id,
      name: '储蓄卡',
      accountType: 'bank',
      openingBalanceMinor: -200,
    );
    expect((await accounts.getById(id))!.name, '储蓄卡');
    expect(await accounts.getBalance(id), -200);
    await expectLater(
      accounts.create(
        name: ' ',
        accountType: 'cash',
        currency: 'CNY',
        openingBalanceMinor: 0,
      ),
      throwsFormatException,
    );
  });

  test('balances isolate accounts and exclude deleted transactions', () async {
    final id = await accounts.create(
      name: '钱包',
      accountType: 'other',
      currency: 'CNY',
      openingBalanceMinor: 1000,
    );
    await ledger.addManual(
      kind: 'income',
      amount: '100',
      categoryId: 'cat_salary',
      accountId: id,
    );
    final expense = await ledger.addManual(
      kind: 'expense',
      amount: '28.50',
      categoryId: 'cat_food',
      accountId: id,
    );
    await ledger.addManual(
      kind: 'expense',
      amount: '1',
      categoryId: 'cat_food',
      accountId: 'acc_cash',
    );
    expect(await accounts.getBalance(id), 8150);
    expect(await accounts.getBalance('acc_cash'), -100);
    await ledger.softDelete(expense);
    expect(await accounts.getBalance(id), 11000);
  });

  test(
    'default fallback, switching, deactivation and restoration preserve history',
    () async {
      expect((await accounts.getDefault())!.id, 'acc_cash');
      final id = await accounts.create(
        name: '微信',
        accountType: 'wechat',
        currency: 'CNY',
        openingBalanceMinor: 0,
      );
      await accounts.setDefault(id);
      expect((await accounts.getDefault())!.id, id);
      final tx = await ledger.addManual(
        kind: 'expense',
        amount: '2',
        categoryId: 'cat_food',
        accountId: id,
      );
      await accounts.deactivate(id);
      expect((await accounts.getDefault())!.id, 'acc_cash');
      expect((await accounts.getAccounts()).length, 2);
      expect((await accounts.getAccounts(activeOnly: true)).length, 1);
      expect((await ledger.watchEntries().first).single.id, tx);
      expect((await ledger.watchEntries().first).single.accountId, id);
      await expectLater(accounts.setDefault(id), throwsStateError);
      await expectLater(accounts.deactivate('acc_cash'), throwsStateError);
      await accounts.restore(id);
      expect((await accounts.getById(id))!.isActive, isTrue);
      expect((await accounts.getDefault())!.id, 'acc_cash');
    },
  );

  test(
    'first new account becomes default when database has no accounts',
    () async {
      await db.close();
      closed = true;
      final emptyDb = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final repo = AccountRepository(emptyDb);
        final id = await repo.create(
          name: '现金',
          accountType: 'cash',
          currency: 'CNY',
          openingBalanceMinor: 0,
        );
        expect((await repo.getDefault())!.id, id);
      } finally {
        await emptyDb.close();
      }
    },
  );
}
