import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/database_provider.dart';
import '../database/app_database.dart';

final automationEngineProvider = FutureProvider<void>((ref) async {
  final servicesDao = ref.read(servicesDaoProvider);
  final transactionsDao = ref.read(transactionsDaoProvider);
  final accountsDao = ref.read(accountsDaoProvider);

  // Obtener servicios activos que tienen autogeneración habilitada
  final activeServices = await servicesDao.watchActiveServices().first;
  final now = DateTime.now();

  for (final service in activeServices) {
    if (service.autoGenerateTransaction && service.nextDate.isBefore(now)) {
      // 1. Necesitamos saber la cuenta. Si no tiene, tomamos la primera activa
      String accountId = service.accountId ?? '';
      if (accountId.isEmpty) {
        final accounts = await accountsDao.watchActiveAccounts().first;
        if (accounts.isNotEmpty) {
          accountId = accounts.first.id;
        } else {
          continue; // No hay cuentas para registrar el movimiento
        }
      }

      // 2. Registrar la transacción
      final isIncome = service.type == 'income';
      await transactionsDao.createTransaction(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          amount: service.amount,
          date: now,
          type: service.type,
          accountId: accountId,
          serviceId: drift.Value(service.id),
          description: drift.Value('Autogenerado: ${service.name}'),
          isRecurring: const drift.Value(true),
        ),
        accountId,
        service.amount,
        isIncome,
      );

      // 3. Reprogramar la próxima fecha
      DateTime nextDate = service.nextDate;
      switch (service.frequency) {
        case 'monthly':
          nextDate = DateTime(now.year, now.month + 1, service.nextDate.day);
          break;
        case 'weekly':
          nextDate = now.add(const Duration(days: 7));
          break;
        case 'yearly':
          nextDate = DateTime(now.year + 1, now.month, service.nextDate.day);
          break;
        case 'once':
          // Desactivar el servicio si era de una sola vez
          await servicesDao.updateService(
            ServicesCompanion(
              id: drift.Value(service.id),
              isActive: const drift.Value(false),
            ),
          );
          continue;
      }

      // 4. Actualizar el servicio
      await servicesDao.updateService(
        ServicesCompanion(
          id: drift.Value(service.id),
          nextDate: drift.Value(nextDate),
        ),
      );
    }
  }
});
