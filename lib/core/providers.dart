import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import '../features/ledger/ledger_repository.dart';
import '../features/planner/planner_repository.dart';

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

final activeTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchTasks();
});

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  return ref.watch(plannerRepositoryProvider).watchJournal();
});
