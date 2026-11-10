import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot/core/database/app_database.dart';
import 'package:lifepilot/features/planner/journal_repository.dart';

void main() {
  late AppDatabase db;
  late JournalRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = JournalRepository(db);
  });
  tearDown(() => db.close());

  test(
    'same-day records, date and keyword filters, editing and permanent delete',
    () async {
      final date = DateTime(2024, 2, 29, 23, 59);
      final first = await repo.create(date: date, title: '春天', content: '今天下雨');
      final second = await repo.create(date: date, content: '天气晴朗');
      final previous = await repo.create(
        date: DateTime(2024, 2, 28),
        title: '昨天',
        content: '旧记录',
      );
      expect((await repo.watch(date: date).first).length, 2);
      expect((await repo.watch(keyword: '春天').first).single.id, first);
      expect(
        (await repo.watch(date: date, keyword: '晴朗').first).single.id,
        second,
      );
      expect((await repo.watch(date: date, keyword: '旧记录').first), isEmpty);
      await repo.update(
        id: first,
        date: DateTime(2024, 3, 1),
        title: '',
        content: '更新后',
      );
      final changed = (await repo.watch(keyword: '更新后').first).single;
      expect(changed.journalDate, '2024-03-01');
      expect(changed.title, isNull);
      expect((await repo.watch(date: date).first).single.id, second);
      await repo.delete(second);
      expect(await repo.watch(date: date).first, isEmpty);
      expect((await repo.watch(keyword: '旧记录').first).single.id, previous);
      await expectLater(repo.delete(second), throwsStateError);
    },
  );

  test('empty content rejected and literal wildcard search', () async {
    await expectLater(
      repo.create(date: DateTime(2026), content: ' \n '),
      throwsFormatException,
    );
    await repo.create(date: DateTime(2026), content: '今天100%开心');
    await repo.create(date: DateTime(2026), content: '其他记录');
    expect((await repo.watch(keyword: '%').first).length, 1);
  });
}
