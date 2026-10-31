import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/ledger/ledger_repository.dart';

void main() {
  test('upgrades a populated V1 database without changing historical data', () async {
    final directory = await Directory.systemTemp.createTemp('lifepilot_v1_');
    final file = File('${directory.path}${Platform.pathSeparator}legacy.sqlite');
    AppDatabase? database;
    try {
      // Construct the original V1 schema directly, before opening AppDatabase.
      final legacy = NativeDatabase(file, setup: (sqlite) {
        sqlite.execute('PRAGMA foreign_keys = ON');
        sqlite.execute('CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, currency TEXT NOT NULL DEFAULT \'CNY\', opening_balance_minor INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)');
        sqlite.execute('CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, parent_id TEXT, sort_order INTEGER NOT NULL DEFAULT 0)');
        sqlite.execute('CREATE TABLE ledger_transactions (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, amount_minor INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT \'CNY\', account_id TEXT NOT NULL REFERENCES accounts(id), target_account_id TEXT REFERENCES accounts(id), category_id TEXT REFERENCES categories(id), refund_of_id TEXT, local_date TEXT NOT NULL, occurred_at_utc INTEGER, time_precision TEXT NOT NULL DEFAULT \'day\', timezone TEXT NOT NULL DEFAULT \'local\', merchant TEXT, note TEXT, source TEXT NOT NULL DEFAULT \'manual\', source_draft_id TEXT UNIQUE, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER)');
        sqlite.execute('CREATE TABLE tasks (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, details TEXT, status TEXT NOT NULL DEFAULT \'todo\', priority INTEGER NOT NULL DEFAULT 1, due_date TEXT, due_at_utc INTEGER, completed_at INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER)');
        sqlite.execute('CREATE TABLE events (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, description TEXT, starts_at_utc INTEGER, ends_at_utc INTEGER, event_date TEXT NOT NULL, all_day INTEGER NOT NULL DEFAULT 1 CHECK (all_day IN (0, 1)), timezone TEXT NOT NULL DEFAULT \'local\', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
        sqlite.execute('CREATE TABLE journal_entries (id TEXT NOT NULL PRIMARY KEY, journal_date TEXT NOT NULL, content TEXT NOT NULL, title TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
        sqlite.execute('CREATE TABLE reminders (id TEXT NOT NULL PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, remind_at_utc INTEGER NOT NULL, status TEXT NOT NULL DEFAULT \'scheduled\', notification_id INTEGER, created_at INTEGER NOT NULL)');
        sqlite.execute('CREATE TABLE app_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
        sqlite.execute("INSERT INTO accounts (id, name, opening_balance_minor, created_at) VALUES ('old_account', '旧账户', 12345, 10)");
        sqlite.execute("INSERT INTO categories (id, name, type) VALUES ('old_expense', '旧支出', 'expense'), ('old_income', '旧收入', 'income')");
        sqlite.execute("INSERT INTO ledger_transactions (id, kind, amount_minor, account_id, category_id, local_date, note, created_at, updated_at) VALUES ('old_expense_tx', 'expense', 2850, 'old_account', 'old_expense', '2025-12-31', '旧备注', 11, 12), ('old_income_tx', 'income', 10000, 'old_account', 'old_income', '2026-01-02', NULL, 13, 14)");
        sqlite.execute('PRAGMA user_version = 1');
      });
      // ensureOpen triggers setup without involving the V2 database class.
      await legacy.ensureOpen(_LegacyUser());
      await legacy.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      final repository = LedgerRepository(database);
      final accounts = await repository.watchAccounts().first;
      final categories = await repository.watchCategories().first;
      final entries = await repository.watchEntries().first;
      expect((await database.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'), 2);
      expect(accounts.single.id, 'old_account');
      expect(accounts.single.openingBalanceMinor, 12345);
      expect(accounts.single.accountType, 'cash');
      expect(accounts.single.isActive, isTrue);
      expect(categories.map((c) => c.id).toSet(), {'old_expense', 'old_income'});
      expect(categories.every((c) => c.isActive && c.iconKey == 'default'), isTrue);
      final byId = {for (final entry in entries) entry.id: entry};
      expect(byId.keys.toSet(), {'old_expense_tx', 'old_income_tx'});
      expect(byId['old_expense_tx']!.amountMinor, 2850);
      expect(byId['old_expense_tx']!.localDate, '2025-12-31');
      expect(byId['old_expense_tx']!.categoryId, 'old_expense');
      expect(byId['old_expense_tx']!.note, '旧备注');
      expect(byId['old_income_tx']!.amountMinor, 10000);
      expect(byId['old_income_tx']!.localDate, '2026-01-02');
      expect(byId['old_income_tx']!.categoryId, 'old_income');
      expect(entries.every((e) => e.accountId == 'old_account'), isTrue);
      expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await database?.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });
}

class _LegacyUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
