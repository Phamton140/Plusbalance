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

  /// Devuelve la primera categoría cuyo nombre coincide (case-insensitive),
  /// opcionalmente excluyendo un id (útil al editar).
  Future<Category?> findByName(String name, {String? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final query = select(categories)
      ..where((c) => c.name.lower().equals(normalized));
    if (excludeId != null) {
      query.where((c) => c.id.equals(excludeId).not());
    }
    return query.getSingleOrNull();
  }

  /// Devuelve el conjunto de colores ya utilizados (en minúsculas), para
  /// poder asignar un color único al crear nuevas categorías.
  Future<Set<String>> getUsedColors() async {
    final all = await select(categories).get();
    return all.map((c) => c.color.toLowerCase()).toSet();
  }
}
