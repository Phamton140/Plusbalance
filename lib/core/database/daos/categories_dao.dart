import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Stream<List<Category>> watchAllCategories() {
    return select(categories).watch();
  }

  Future<int> createCategory(Insertable<Category> category) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(Insertable<Category> category) {
    return update(categories).replace(category);
  }

  Future<int> deleteCategory(String id) {
    return (delete(categories)..where((c) => c.id.equals(id))).go();
  }
}
