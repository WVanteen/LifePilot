import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/categories/category_repository.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaults();
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());
  test('create, edit, duplicate, sorting, disable and restore', () async {
    expect(
      (await repo.watch(type: 'income').first).every((c) => c.type == 'income'),
      isTrue,
    );
    expect(
      (await repo.watch(type: 'expense').first).every(
        (c) => c.type == 'expense',
      ),
      isTrue,
    );
    final id = await repo.create(name: '自定义', type: 'expense', iconKey: 'food');
    await expectLater(
      repo.create(name: ' 自定义 ', type: 'expense', iconKey: 'default'),
      throwsFormatException,
    );
    await repo.update(id: id, name: '新名称', iconKey: 'health');
    var rows = await repo.watch(type: 'expense').first;
    expect(rows.last.name, '新名称');
    expect(rows.last.iconKey, 'health');
    await repo.move(id, -1);
    rows = await repo.watch(type: 'expense').first;
    expect(rows[rows.length - 2].id, id);
    await repo.setActive(id, false);
    expect(
      (await repo.watch(type: 'expense', activeOnly: true).first).any(
        (c) => c.id == id,
      ),
      isFalse,
    );
    await repo.setActive(id, true);
    expect(
      (await repo.watch(type: 'expense', activeOnly: true).first).any(
        (c) => c.id == id,
      ),
      isTrue,
    );
  });
  test(
    'inactive category preserves history but cannot be used for new or other entries',
    () async {
      final ledger = LedgerRepository(db);
      final id = await ledger.addManual(
        kind: 'expense',
        amount: '10',
        categoryId: 'cat_food',
      );
      await repo.setActive('cat_food', false);
      await expectLater(
        ledger.addManual(kind: 'expense', amount: '1', categoryId: 'cat_food'),
        throwsFormatException,
      );
      await ledger.updateManual(
        id: id,
        kind: 'expense',
        amount: '12',
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        transactionDate: DateTime(2026),
      );
      final entry = (await ledger.watchEntries().first).single;
      expect(entry.categoryId, 'cat_food');
      expect(entry.amountMinor, 1200);
    },
  );
  test('last active category cannot be disabled', () async {
    final rows = await repo.watch(type: 'income', activeOnly: true).first;
    for (final c in rows.skip(1)) {
      await repo.setActive(c.id, false);
    }
    await expectLater(repo.setActive(rows.first.id, false), throwsStateError);
  });
}
