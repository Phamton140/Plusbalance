import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/providers/services_providers.dart';
import '../../../core/database/app_database.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lateAsync = ref.watch(lateServicesProvider);
    final upcomingAsync = ref.watch(upcomingServicesProvider);

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
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
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
                                      '¡Saldo insuficiente (\$${s.amount.toStringAsFixed(2)})! Recarga y paga manualmente.',
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
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
                  final upcomingServices = services.where((s) => s.status != 'late').toList();
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
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 24, right: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
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
                                      'Monto: \$${s.amount.toStringAsFixed(2)} - Se debita $daysText',
                                      style: const TextStyle(color: Colors.orange, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
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

              // NO NOTIFICATIONS
              Consumer(
                builder: (context, ref, child) {
                  final lateList = ref.watch(lateServicesProvider).value ?? <Service>[];
                  final upcomingList = (ref.watch(upcomingServicesProvider).value ?? <Service>[]).where((s) => s.status != 'late').toList();

                  if (lateList.isEmpty && upcomingList.isEmpty) {
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
