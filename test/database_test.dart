import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';
import 'package:lifepilot/features/planner/planner_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
  });
  tearDown(() async => db.close());

  test('initialization seeds exactly one default account', () async {
    await db.seedDefaults();
    final accounts = await db.select(db.accounts).get();
    expect(accounts.length, 1);
    expect(accounts.single.id, 'acc_cash');
    expect((await db.select(db.categories).get()).isNotEmpty, isTrue);
  });

  test('ledger insert and soft delete persist correctly', () async {
    final repository = LedgerRepository(db);
    final id = await repository.addManual(kind: 'expense', amount: '28.50', categoryId: 'cat_food');
    var entries = await repository.watchEntries().first;
    expect(entries.length, 1);
    expect(entries.first.amountMinor, 2850);
    await repository.softDelete(id);
    entries = await repository.watchEntries().first;
    expect(entries, isEmpty);
  });

  test('tasks can be created and completed', () async {
    final repository = PlannerRepository(db);
    await repository.addTask('完成操作系统实验');
    final tasks = await repository.watchTasks().first;
    expect(tasks.single.status, 'todo');
    await repository.toggleTask(tasks.single);
    final updated = await repository.watchTasks().first;
    expect(updated.single.status, 'done');
  });

  test('inactive account rejects new entries but preserves existing entries', () async {
    final repository = LedgerRepository(db);
    final id = await repository.addManual(kind: 'expense', amount: '10', categoryId: 'cat_food');
    await (db.update(db.accounts)..where((a) => a.id.equals('acc_cash')))
        .write(const AccountsCompanion(isActive: Value(false)));
    await expectLater(
      repository.addManual(kind: 'expense', amount: '5', categoryId: 'cat_food'),
      throwsFormatException,
    );
    await repository.updateManual(id: id, kind: 'expense', amount: '12', categoryId: 'cat_food', accountId: 'acc_cash', transactionDate: DateTime(2026, 1, 1));
    expect((await repository.watchEntries().first).single.amountMinor, 1200);
  });
}
