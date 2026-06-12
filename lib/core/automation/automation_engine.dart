import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/database_provider.dart';
import '../database/app_database.dart';
import '../../features/services/domain/service_scheduler.dart';

/// Core automation logic - extracted to be reusable
Future<void> runAutomationEngine(Ref ref) async {
  final servicesDao = ref.read(servicesDaoProvider);
  final transactionsDao = ref.read(transactionsDaoProvider);
  final accountsDao = ref.read(accountsDaoProvider);

  final activeServices = await servicesDao.watchActiveServices().first;
  final now = DateTime.now();

  for (final service in activeServices) {
    if (service.autoGenerateTransaction && service.nextDate.isBefore(now) && service.status != 'late') {
      String accountId = service.accountId ?? '';
      if (accountId.isEmpty) {
        final accounts = await accountsDao.watchActiveAccounts().first;
        if (accounts.isNotEmpty) {
          accountId = accounts.first.id;
        } else {
          continue;
        }
      }

      final account = await (accountsDao.select(accountsDao.accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account == null) continue;

      final isExpense = service.type == 'expense';
      
      if (isExpense && account.balance < service.amount) {
        await servicesDao.updateService(
          service.copyWith(
            status: 'late',
            updatedAt: DateTime.now(),
          ),
        );
        continue;
      }

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
          sourceType: const drift.Value('service'),
        ),
        accountId,
        service.amount,
        isIncome,
      );

      final nextDate = ServiceScheduler.nextDateForService(service: service, now: now);
      if (nextDate == null) {
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
}

/// Provider that runs automation once on app startup (when authenticated)
final automationEngineProvider = FutureProvider<void>((ref) async {
  await runAutomationEngine(ref);
});

/// Provider to manually trigger automation (e.g., from settings or pull-to-refresh)
final triggerAutomationProvider = FutureProvider<void>((ref) async {
  await runAutomationEngine(ref);
});
