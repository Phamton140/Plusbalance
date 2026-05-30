import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'services_dao.g.dart';

@DriftAccessor(tables: [Services])
class ServicesDao extends DatabaseAccessor<AppDatabase> with _$ServicesDaoMixin {
  ServicesDao(super.db);

  Stream<List<Service>> watchActiveServices() {
    return (select(services)..where((s) => s.isActive.equals(true))).watch();
  }

  Future<int> createService(Insertable<Service> service) {
    return into(services).insert(service);
  }

  Future<bool> updateService(Insertable<Service> service) {
    return update(services).replace(service);
  }

  Future<int> deleteService(String id) {
    return (delete(services)..where((s) => s.id.equals(id))).go();
  }
}
