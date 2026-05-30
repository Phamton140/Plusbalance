import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<String?> watchSetting(String key) {
    return (select(settings)..where((s) => s.key.equals(key)))
        .map((s) => s.value)
        .watchSingleOrNull();
  }

  Future<String?> getSetting(String key) async {
    final result = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insert(
      Setting(key: key, value: value, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteSetting(String key) {
    return (delete(settings)..where((s) => s.key.equals(key))).go();
  }
}
