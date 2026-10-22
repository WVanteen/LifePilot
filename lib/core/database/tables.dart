import 'package:drift/drift.dart';

// All stored timestamps use UTC milliseconds. A local YYYY-MM-DD is retained
// for date-only journal records and future time-zone-aware reports.

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get openingBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // expense | income
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class LedgerTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // expense | income | transfer | refund
  IntColumn get amountMinor => integer()(); // non-negative minor units
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get targetAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get refundOfId => text().nullable()();
  TextColumn get localDate => text()(); // YYYY-MM-DD in original timezone
  IntColumn get occurredAtUtc => integer().nullable()();
  TextColumn get timePrecision => text().withDefault(const Constant('day'))();
  TextColumn get timezone => text().withDefault(const Constant('local'))();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceDraftId => text().nullable().unique()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get details => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  TextColumn get dueDate => text().nullable()(); // date-only in Week 1
  IntColumn get dueAtUtc => integer().nullable()(); // reserved for precise deadlines
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get startsAtUtc => integer().nullable()();
  IntColumn get endsAtUtc => integer().nullable()();
  TextColumn get eventDate => text()();
  BoolColumn get allDay => boolean().withDefault(const Constant(true))();
  TextColumn get timezone => text().withDefault(const Constant('local'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get journalDate => text()();
  TextColumn get content => text()();
  TextColumn get title => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get remindAtUtc => integer()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  IntColumn get notificationId => integer().nullable()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}
