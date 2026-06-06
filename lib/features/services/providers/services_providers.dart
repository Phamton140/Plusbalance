import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

final lateServicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesDaoProvider).watchLateServices();
});

final upcomingServicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesDaoProvider).watchUpcomingServices();
});
