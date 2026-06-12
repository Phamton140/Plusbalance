import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class AccountRecharge {
  final Account account;
  final DateTime nextDate;
  final int daysFromNow; // negativo = atrasado
  final int installment; // 1, 2... (1ra, 2da quincena, etc.)
  final double? amount;

  const AccountRecharge({
    required this.account,
    required this.nextDate,
    required this.daysFromNow,
    required this.installment,
    this.amount,
  });
}

/// Devuelve la lista de recargas próximas (≤7 días o vencidas).
/// Para cuentas quincenales emite DOS entradas (1ra y 2da fecha).
final upcomingAccountRechargesProvider =
    StreamProvider.autoDispose<List<AccountRecharge>>((ref) {
  return ref.watch(accountsDaoProvider).watchActiveAccounts().map((accounts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 7));

    final result = <AccountRecharge>[];
    for (final a in accounts) {
      final f = a.rechargeFrequency;
      if (f == null || f.isEmpty || f == 'none') continue;

      void add(DateTime? next, int installment, double? amount) {
        if (next == null) return;
        final nd = DateTime(next.year, next.month, next.day);
        if (nd.isAfter(horizon)) return;
        result.add(AccountRecharge(
          account: a,
          nextDate: nd,
          daysFromNow: nd.difference(today).inDays,
          installment: installment,
          amount: amount,
        ));
      }

      add(a.rechargeNextDate, 1, a.rechargeAmount);
      if (f == 'biweekly') {
        add(a.rechargeNextDate2, 2, a.rechargeAmount2);
      }
    }
    result.sort((x, y) => x.nextDate.compareTo(y.nextDate));
    return result;
  });
});