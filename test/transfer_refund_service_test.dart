import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';
import 'package:lifepilot/features/accounts/account_repository.dart';
import 'package:lifepilot/features/ledger/transfer_refund_service.dart';

void main() {
  late AppDatabase db;
  late TransferRefundService service;
  final date = DateTime(2026, 11, 8);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(id: 'bank', name: '银行卡', createdAt: 1),
        );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'inactive',
            name: '停用',
            createdAt: 2,
            isActive: const Value(false),
          ),
        );
    service = TransferRefundService(db);
  });
  tearDown(() => db.close());

  test(
    'transfer is atomic, validates accounts, supports edit delete restore and idempotency',
    () async {
      final id = await service.addTransfer(
        operationId: 'one',
        accountId: 'acc_cash',
        targetAccountId: 'bank',
        amountMinor: 1001,
        date: date,
      );
      final accounts = AccountRepository(db);
      expect(await accounts.getBalance('acc_cash'), -1001);
      expect(await accounts.getBalance('bank'), 1001);
      await expectLater(
        service.addTransfer(
          operationId: 'one',
          accountId: 'acc_cash',
          targetAccountId: 'bank',
          amountMinor: 1001,
          date: date,
        ),
        throwsStateError,
      );
      await expectLater(
        service.addTransfer(
          operationId: 'two',
          accountId: 'bank',
          targetAccountId: 'bank',
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
      await expectLater(
        service.addTransfer(
          operationId: 'three',
          accountId: 'bank',
          targetAccountId: 'inactive',
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
      await service.editTransfer(
        id: id,
        accountId: 'bank',
        targetAccountId: 'acc_cash',
        amountMinor: 505,
        date: date,
      );
      var entry = (await db.select(db.ledgerTransactions).get()).single;
      expect(entry.accountId, 'bank');
      expect(entry.targetAccountId, 'acc_cash');
      expect(entry.amountMinor, 505);
      await service.delete(id);
      expect(await accounts.getBalance('acc_cash'), 0);
      expect(await accounts.getBalance('bank'), 0);
      expect((await LedgerRepository(db).watchEntries().first), isEmpty);
      await service.restore(id);
      expect(await accounts.getBalance('acc_cash'), 505);
      expect(await accounts.getBalance('bank'), -505);
      entry = (await LedgerRepository(db).watchEntries().first).single;
      expect(entry.kind, 'transfer');
      final summary = await LedgerRepository(db).watchMonthSummary(date).first;
      expect(summary.incomeMinor, 0);
      expect(summary.expenseMinor, 0);
    },
  );

  test(
    'partial refunds reject duplicates and excess; edit/delete/restore respect total',
    () async {
      final ledger = LedgerRepository(db);
      final expense = await ledger.addManual(
        kind: 'expense',
        amount: '10.00',
        categoryId: 'cat_food',
        transactionDate: date,
      );
      final first = await service.addRefund(
        operationId: 'refund-1',
        expenseId: expense,
        amountMinor: 400,
        date: date,
      );
      expect(await AccountRepository(db).getBalance('acc_cash'), -600);
      expect((await ledger.watchMonthSummary(date).first).expenseMinor, 600);
      expect(
        (await ledger.watchMonthExpenseByCategory(date).first)
            .single
            .amountMinor,
        600,
      );
      await expectLater(ledger.softDelete(expense), throwsStateError);
      final second = await service.addRefund(
        operationId: 'refund-2',
        expenseId: expense,
        amountMinor: 600,
        date: date,
      );
      await expectLater(
        service.addRefund(
          operationId: 'refund-1',
          expenseId: expense,
          amountMinor: 1,
          date: date,
        ),
        throwsStateError,
      );
      await expectLater(
        service.addRefund(
          operationId: 'refund-3',
          expenseId: expense,
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
      await expectLater(
        service.editRefund(id: first, amountMinor: 401, date: date),
        throwsFormatException,
      );
      await service.delete(second);
      expect(await AccountRepository(db).getBalance('acc_cash'), -600);
      await service.editRefund(id: first, amountMinor: 500, date: date);
      await expectLater(service.restore(second), throwsFormatException);
      await service.editRefund(id: first, amountMinor: 400, date: date);
      await service.restore(second);
      final records = await db.select(db.ledgerTransactions).get();
      final refund = records.singleWhere((r) => r.id == first);
      expect(refund.refundOfId, expense);
      expect(refund.categoryId, 'cat_food');
      expect(refund.accountId, 'acc_cash');
      expect(records.where((r) => r.kind == 'refund').length, 2);
    },
  );

  test(
    'refund rejects invalid or deleted expense and inactive account',
    () async {
      final ledger = LedgerRepository(db);
      final expense = await ledger.addManual(
        kind: 'expense',
        amount: '2.00',
        categoryId: 'cat_food',
      );
      await expectLater(
        service.addRefund(
          operationId: 'missing',
          expenseId: 'missing',
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
      await (db.update(db.accounts)..where((a) => a.id.equals('acc_cash')))
          .write(const AccountsCompanion(isActive: Value(false)));
      await expectLater(
        service.addRefund(
          operationId: 'inactive',
          expenseId: expense,
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
      await ledger.softDelete(expense);
      await expectLater(
        service.addRefund(
          operationId: 'deleted',
          expenseId: expense,
          amountMinor: 1,
          date: date,
        ),
        throwsFormatException,
      );
    },
  );
}
