import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class AccountRecharge {
  final Account account;
  final DateTime nextDate;
  final int daysFromNow; // negativo = atrasado
  const AccountRecharge({
    required this.account,
    required this.nextDate,
    required this.daysFromNow,
  });
}

/// Devuelve la lista de cuentas con recarga configurada cuya próxima
/// fecha está dentro de los próximos 7 días (o ya vencida).
final upcomingAccountRechargesProvider =
    StreamProvider<List<AccountRecharge>>((ref) {
  return ref.watch(accountsDaoProvider).watchActiveAccounts().map((accounts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 7));

    final result = <AccountRecharge>[];
    for (final a in accounts) {
      final f = a.rechargeFrequency;
      if (f == null || f.isEmpty || f == 'none') continue;
      final next = a.rechargeNextDate;
      if (next == null) continue;
      final nd = DateTime(next.year, next.month, next.day);
      if (nd.isAfter(horizon)) continue;
      result.add(AccountRecharge(
        account: a,
        nextDate: nd,
        daysFromNow: nd.difference(today).inDays,
      ));
    }
    result.sort((x, y) => x.nextDate.compareTo(y.nextDate));
    return result;
  });
});
