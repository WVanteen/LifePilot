import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';

class CategoryRepository {
  CategoryRepository(this.db);
  final AppDatabase db;

  Stream<List<Category>> watch({String? type, bool activeOnly = false}) {
    final query = db.select(db.categories)
      ..where(
        (c) =>
            (type == null ? const Constant(true) : c.type.equals(type)) &
            (activeOnly ? c.isActive.equals(true) : const Constant(true)),
      )
      ..orderBy([
        (c) => OrderingTerm(expression: c.sortOrder),
        (c) => OrderingTerm(expression: c.id),
      ]);
    return query.watch();
  }

  Future<String> create({
    required String name,
    required String type,
    required String iconKey,
  }) => db.transaction(() async {
    final clean = await _validate(name, type);
    final rows = await (db.select(
      db.categories,
    )..where((c) => c.type.equals(type))).get();
    final order =
        rows.fold<int>(-1, (max, c) => c.sortOrder > max ? c.sortOrder : max) +
        1;
    final id = const Uuid().v4();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: clean,
            type: type,
            iconKey: Value(iconKey),
            sortOrder: Value(order),
          ),
        );
    return id;
  });

  Future<void> update({
    required String id,
    required String name,
    required String iconKey,
  }) => db.transaction(() async {
    final category = await _get(id);
    final clean = await _validate(name, category.type, exceptId: id);
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(clean), iconKey: Value(iconKey)),
    );
  });

  Future<void> setActive(String id, bool active) => db.transaction(() async {
    final category = await _get(id);
    if (!active && category.isActive) {
      final enabled =
          await (db.select(db.categories)..where(
                (c) => c.type.equals(category.type) & c.isActive.equals(true),
              ))
              .get();
      if (enabled.length <= 1) throw StateError('每种收支类型至少保留一个启用分类');
    }
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(isActive: Value(active)),
    );
  });

  Future<void> move(String id, int direction) => db.transaction(() async {
    final category = await _get(id);
    final rows =
        await (db.select(db.categories)
              ..where((c) => c.type.equals(category.type))
              ..orderBy([
                (c) => OrderingTerm(expression: c.sortOrder),
                (c) => OrderingTerm(expression: c.id),
              ]))
            .get();
    final index = rows.indexWhere((c) => c.id == id);
    final target = index + direction;
    if ((direction != -1 && direction != 1) ||
        target < 0 ||
        target >= rows.length) {
      return;
    }
    final item = rows.removeAt(index);
    rows.insert(target, item);
    for (var i = 0; i < rows.length; i++) {
      await (db.update(db.categories)..where((c) => c.id.equals(rows[i].id)))
          .write(CategoriesCompanion(sortOrder: Value(i)));
    }
  });

  Future<Category> _get(String id) async =>
      (await (db.select(
        db.categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull()) ??
      (throw StateError('分类不存在'));
  Future<String> _validate(String name, String type, {String? exceptId}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const FormatException('分类名称不能为空');
    if (type != 'income' && type != 'expense') {
      throw const FormatException('分类类型无效');
    }
    final rows = await (db.select(
      db.categories,
    )..where((c) => c.type.equals(type))).get();
    if (rows.any(
      (c) =>
          c.id != exceptId &&
          c.name.trim().toLowerCase() == clean.toLowerCase(),
    )) {
      throw const FormatException('该类型已有同名分类');
    }
    return clean;
  }
}
