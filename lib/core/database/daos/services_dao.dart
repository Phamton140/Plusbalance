import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'services_dao.g.dart';

@DriftAccessor(tables: [Services])
class ServicesDao extends DatabaseAccessor<AppDatabase> with _$ServicesDaoMixin {
  ServicesDao(super.db);

  Stream<List<Service>> watchActiveServices() {
    return (select(services)..where((t) => t.isActive.equals(true))).watch();
  }

  Stream<List<Service>> watchLateServices() {
    return (select(services)
      ..where((t) => t.isActive.equals(true))
      ..where((t) => t.status.equals('late'))
    ).watch();
  }

  Stream<List<Service>> watchUpcomingServices() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next7Days = today.add(const Duration(days: 7, hours: 23, minutes: 59, seconds: 59));
    
    return (select(services)
      ..where((t) => t.isActive.equals(true))
      ..where((t) => t.nextDate.isBetweenValues(today, next7Days))
      ..orderBy([(t) => OrderingTerm(expression: t.nextDate, mode: OrderingMode.asc)])
    ).watch();
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
