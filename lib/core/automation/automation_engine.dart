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
    if (service.autoGenerateTransaction && service.nextDate.isBefore(now) && service.status != 'late') {
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

      // Verificamos el saldo de la cuenta
      final account = await (accountsDao.select(accountsDao.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account == null) continue;

      final isExpense = service.type == 'expense';
      
      if (isExpense && account.balance < service.amount) {
        // No hay saldo suficiente, marcar como atrasado
        await servicesDao.updateService(
          service.copyWith(
            status: 'late',
            updatedAt: DateTime.now(),
          ),
        );
        continue; // No generamos transacción ni avanzamos la fecha
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
          categoryId: drift.Value(service.categoryId),
          description: drift.Value('Autogenerado: ${service.name}'),
          isRecurring: const drift.Value(true),
        ),
        accountId,
        service.amount,
        isIncome,
      );

      // 3. Reprogramar la próxima fecha
      DateTime nextDate = service.nextDate;
      if (service.frequency == 'monthly') {
        nextDate = DateTime(now.year, now.month + 1, service.nextDate.day);
      } else if (service.frequency.startsWith('weekly')) {
        if (service.frequency == 'weekly') {
          nextDate = now.add(const Duration(days: 7));
        } else {
          // Parse weekly:1,3,5
          try {
            final daysStr = service.frequency.split(':')[1];
            final days = daysStr.split(',').map(int.parse).toList();
            days.sort();
            final currentDay = now.weekday;
            int daysToAdd = 7;
            for (int d in days) {
              if (d > currentDay) {
                daysToAdd = d - currentDay;
                break;
              }
            }
            if (daysToAdd == 7 && days.isNotEmpty) {
              daysToAdd = (7 - currentDay) + days.first;
            }
            nextDate = now.add(Duration(days: daysToAdd));
          } catch (e) {
            nextDate = now.add(const Duration(days: 7));
          }
        }
      } else if (service.frequency == 'yearly') {
        nextDate = DateTime(now.year + 1, now.month, service.nextDate.day);
      } else if (service.frequency == 'once') {
        await servicesDao.updateService(
          service.copyWith(
            isActive: false,
            status: 'active',
            updatedAt: DateTime.now(),
          ),
        );
        continue;
      }

      await servicesDao.updateService(
        service.copyWith(
          nextDate: nextDate,
          status: 'active',
          updatedAt: DateTime.now(),
        ),
      );
    }
  }
});
