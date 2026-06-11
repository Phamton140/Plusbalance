import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/providers/services_providers.dart';
import '../../accounts/domain/account_constants.dart';
import '../providers/recharge_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _confirmAndApplyService(
    BuildContext context,
    WidgetRef ref,
    Service s,
  ) async {
    final accountName = s.accountId == null
        ? '(sin cuenta)'
        : (await ref
                .read(accountsDaoProvider)
                .watchActiveAccounts()
                .first)
            .firstWhere(
              (a) => a.id == s.accountId,
              orElse: () => Account(
                id: '',
                name: 'desconocida',
                type: '',
                balance: 0,
                color: '',
                isArchived: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                currency: '',
              ),
            )
            .name;

    final isIncome = s.type == 'income';
    final action = isIncome ? 'Registrar ingreso' : 'Aplicar pago';
    final subject = isIncome ? 'el cobro' : 'el pago';
    final txVerb = isIncome ? 'acreditado a' : 'debita de';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action: ${s.name}'),
        content: Text(
          'Se registrará ${isIncome ? "el ingreso" : "el gasto"} de '
          '\$${s.amount.toStringAsFixed(2)} con fecha de hoy, '
          'que se $txVerb la cuenta "$accountName".\n\n'
          'La fecha del próximo $subject se moverá al siguiente ciclo '
          'y esta notificación desaparecerá.\n\n'
          '¿Confirmas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await ref.read(transactionsDaoProvider).applyServicePayment(s);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isIncome ? "Ingreso" : "Pago"} aplicado: ${s.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndApplyRecharge(
    BuildContext context,
    WidgetRef ref,
    AccountRecharge r,
  ) async {
    final isBiweekly = r.account.rechargeFrequency == 'biweekly';
    final installmentLabel = isBiweekly ? ' (${r.installment}da)' : '';
    final amount = r.amount;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Esta recarga no tiene un monto configurado, no se puede aplicar.')),
      );
      return;
    }
    final concept = r.account.rechargeLabel?.isNotEmpty == true
        ? r.account.rechargeLabel!
        : r.account.name;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aplicar recarga a ${r.account.name}$installmentLabel'),
        content: Text(
          'Se registrará un ingreso de \$${amount.toStringAsFixed(2)} '
          '("$concept") con fecha de hoy, que se sumará al saldo de '
          'la cuenta "${r.account.name}".\n\n'
          'La próxima fecha de esta recarga se moverá al siguiente ciclo '
          'y la notificación desaparecerá.\n\n'
          '¿Confirmas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar recarga'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await ref.read(transactionsDaoProvider).applyAccountRecharge(
            account: r.account,
            amount: amount,
            installment: r.installment,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Recarga aplicada: +\$${amount.toStringAsFixed(2)} a ${r.account.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lateAsync = ref.watch(lateServicesProvider);
    final upcomingAsync = ref.watch(upcomingServicesProvider);
    final rechargesAsync = ref.watch(upcomingAccountRechargesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LATE SERVICES
              lateAsync.when(
                data: (services) {
                  if (services.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text('Pagos Atrasados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      ...services.map((s) {
                        final isIncome = s.type == 'income';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isIncome
                                              ? 'Ingreso de \$${s.amount.toStringAsFixed(2)} atrasado.'
                                              : '¡Saldo insuficiente (\$${s.amount.toStringAsFixed(2)})! Recarga y paga manualmente.',
                                          style: const TextStyle(color: Colors.red, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(isIncome
                                      ? 'Aplicar ingreso'
                                      : 'Aplicar pago'),
                                  onPressed: () =>
                                      _confirmAndApplyService(context, ref, s),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox(),
              ),

              // UPCOMING SERVICES
              upcomingAsync.when(
                data: (services) {
                  final upcomingServices =
                      services.where((s) => s.status != 'late').toList();
                  if (upcomingServices.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text('Próximos Pagos (7 días)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                      ...upcomingServices.map((s) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final target = DateTime(s.nextDate.year, s.nextDate.month, s.nextDate.day);
                        final days = target.difference(today).inDays;

                        String daysText;
                        if (days <= 0) {
                          daysText = '¡Hoy!';
                        } else if (days == 1) {
                          daysText = 'en 1 día';
                        } else {
                          daysText = 'en $days días';
                        }
                        final isIncome = s.type == 'income';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${isIncome ? "Ingreso" : "Monto"}: \$${s.amount.toStringAsFixed(2)} - ${isIncome ? "se acredita" : "se debita"} $daysText',
                                          style: const TextStyle(color: Colors.orange, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(isIncome
                                      ? 'Aplicar ahora'
                                      : 'Pagar ahora'),
                                  onPressed: () =>
                                      _confirmAndApplyService(context, ref, s),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox(),
              ),

              // UPCOMING ACCOUNT RECHARGES
              rechargesAsync.when(
                data: (recharges) {
                  if (recharges.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text('Recargas próximas (7 días)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.teal)),
                      ),
                      ...recharges.map((r) {
                        final String daysText;
                        final Color color;
                        if (r.daysFromNow < 0) {
                          daysText = 'vencida hace ${-r.daysFromNow}d';
                          color = Colors.red;
                        } else if (r.daysFromNow == 0) {
                          daysText = '¡Hoy!';
                          color = Colors.teal;
                        } else if (r.daysFromNow == 1) {
                          daysText = 'mañana';
                          color = Colors.teal;
                        } else {
                          daysText = 'en ${r.daysFromNow} días';
                          color = Colors.teal;
                        }

                        final freq = kRechargeFrequencyLabels[
                                r.account.rechargeFrequency] ??
                            r.account.rechargeFrequency;
                        final isBiweekly =
                            r.account.rechargeFrequency == 'biweekly';
                        final installmentLabel =
                            isBiweekly ? ' (${r.installment}da)' : '';
                        final concept = r.account.rechargeLabel?.isNotEmpty == true
                            ? ' · ${r.account.rechargeLabel}'
                            : '';
                        final amount = r.amount != null
                            ? ' ~ \$${r.amount!.toStringAsFixed(0)}'
                            : '';
                        final canApply = r.amount != null && r.amount! > 0;

                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 8, left: 24, right: 24),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            border:
                                Border.all(color: color.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.autorenew, color: color, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Recarga a ${r.account.name}$installmentLabel',
                                          style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$freq$concept$amount · $daysText',
                                          style: TextStyle(
                                              color: color, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Aplicar recarga'),
                                  onPressed: canApply
                                      ? () => _confirmAndApplyRecharge(context, ref, r)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (e, s) => const SizedBox(),
              ),

              // NO NOTIFICATIONS
              Consumer(
                builder: (context, ref, _) {
                  final lateList = ref.watch(lateServicesProvider).value ?? <Service>[];
                  final upcomingList = (ref.watch(upcomingServicesProvider).value ?? <Service>[]).where((s) => s.status != 'late').toList();
                  final rechargeList = ref.watch(upcomingAccountRechargesProvider).value ?? [];

                  if (lateList.isEmpty && upcomingList.isEmpty && rechargeList.isEmpty) {
                    return Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No hay notificaciones', style: TextStyle(color: Colors.grey, fontSize: 18)),
                        ],
                      ),
                    );
                  }
                  return const SizedBox();
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
