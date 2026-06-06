import '../../../core/database/app_database.dart';

class ServiceScheduler {
  const ServiceScheduler._();

  /// Calcula la próxima fecha de cobro para un servicio recurrente.
  ///
  /// Frecuencias soportadas:
  /// - `monthly`: mismo día del mes siguiente.
  /// - `weekly`: cada 7 días desde [now].
  /// - `weekly:1,3,5` (u otra lista CSV): próximo día de la semana que coincida.
  /// - `yearly`: mismo día y mes del año siguiente.
  ///
  /// Retorna `null` para `once` u otras frecuencias no recurrentes; en ese caso
  /// el caller es responsable de desactivar el servicio.
  static DateTime? nextDateForService({
    required Service service,
    required DateTime now,
  }) {
    switch (service.frequency) {
      case 'monthly':
        return DateTime(now.year, now.month + 1, service.nextDate.day);
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(now.year + 1, now.month, service.nextDate.day);
      case 'once':
        return null;
    }

    if (service.frequency.startsWith('weekly:')) {
      try {
        final daysStr = service.frequency.split(':')[1];
        final List<int> days = daysStr.split(',').map(int.parse).toList()..sort();
        if (days.isEmpty) {
          return now.add(const Duration(days: 7));
        }
        final int currentDay = now.weekday;
        int daysToAdd = 7;
        for (final d in days) {
          if (d > currentDay) {
            daysToAdd = d - currentDay;
            break;
          }
        }
        if (daysToAdd == 7) {
          daysToAdd = (7 - currentDay) + days.first;
        }
        return now.add(Duration(days: daysToAdd));
      } catch (_) {
        return now.add(const Duration(days: 7));
      }
    }

    return service.nextDate;
  }
}
