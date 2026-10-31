import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import '../features/ledger/ledger_repository.dart';
import '../features/planner/planner_repository.dart';
import '../features/accounts/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) =>
    AccountRepository(ref.watch(appDatabaseProvider)));

final managedAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) =>
    ref.watch(accountRepositoryProvider).watchAccounts());

final accountBalanceProvider = StreamProvider.autoDispose.family<int, String>((ref, id) =>
    ref.watch(accountRepositoryProvider).watchBalance(id));

final defaultAccountProvider = FutureProvider.autoDispose<Account?>((ref) {
  ref.watch(managedAccountsProvider);
  return ref.watch(accountRepositoryProvider).getDefault();
});

// In main.dart this provider is overridden with one pre-seeded database instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('appDatabaseProvider must be overridden in main()');
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(ref.watch(appDatabaseProvider));
});

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  return PlannerRepository(ref.watch(appDatabaseProvider));
});

final ledgerEntriesProvider = StreamProvider<List<LedgerTransaction>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchEntries();
});

final ledgerCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchCategories();
});

final ledgerAccountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAccounts();
});

final currentMonthLedgerSummaryProvider = StreamProvider<LedgerSummary>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchMonthSummary(DateTime.now());
});

final currentMonthCategoryExpensesProvider =
    StreamProvider<List<CategoryExpenseTotal>>((ref) {
      return ref
          .watch(ledgerRepositoryProvider)
          .watchMonthExpenseByCategory(DateTime.now());
    });

final activeTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchTasks();
});

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchJournal();
});
