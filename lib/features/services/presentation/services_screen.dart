import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/category_icons.dart';
import '../domain/service_scheduler.dart';
import 'screens/service_form_screen.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesStream = ref.watch(servicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios y Suscripciones'),
      ),
      body: servicesStream.when(
        data: (services) {
          if (services.isEmpty) {
            return const Center(
              child: Text(
                'No has registrado servicios ni nóminas.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final isIncome = service.type == 'income';
              final isNeed = service.label == 'need';
              
              return Dismissible(
                key: Key(service.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Eliminar Servicio"),
                        content: const Text("¿Estás seguro de eliminar este servicio? Las transacciones pasadas no se borrarán."),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.of(context).pop(true), 
                            child: const Text("Eliminar")
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  await ref.read(servicesDaoProvider).deleteService(service.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio eliminado')));
                  }
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(int.parse(service.color.replaceAll('#', '0xFF'))),
                      child: Icon(iconFromCodePoint(service.icon), color: Colors.white),
                    ),
                    title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            String freqText = service.frequency.toUpperCase();
                            if (service.frequency.startsWith('weekly:')) {
                              final days = service.frequency.split(':')[1].split(',');
                              freqText = 'SEMANAL (Días: ${days.join(', ')})';
                            }
                            return Text('$freqText - Próximo cobro: ${service.nextDate.day}/${service.nextDate.month}/${service.nextDate.year}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                          }
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isNeed ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isNeed ? 'Lo Necesito' : 'Lo Quiero',
                            style: TextStyle(fontSize: 10, color: isNeed ? Colors.blue : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}\$${service.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900, 
                            color: isIncome ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        if (service.status == 'late')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: const Size(60, 24),
                            ),
                            onPressed: () => _payLateService(context, ref, service),
                            child: const Text('PAGAR', style: TextStyle(fontSize: 10, color: Colors.white)),
                          )
                        else if (service.autoGenerateTransaction)
                          const Icon(Icons.autorenew, size: 14, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ServiceFormScreen(service: service)),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServiceFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Registrar Servicio'),
      ),
    );
  }

}

Future<void> _payLateService(BuildContext context, WidgetRef ref, Service service) async {
    final surchargeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pagar Servicio Atrasado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Monto base: \$${service.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: surchargeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Recargo por mora (Opcional)', hintText: 'Ej. 5.00'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final surcharge = double.tryParse(surchargeController.text) ?? 0.0;
                final totalAmount = service.amount + surcharge;
                
                final servicesDao = ref.read(servicesDaoProvider);
                final transactionsDao = ref.read(transactionsDaoProvider);
                
                String accountId = service.accountId ?? '';
                if (accountId.isEmpty) {
                  final accounts = await ref.read(accountsDaoProvider).watchActiveAccounts().first;
                  if (accounts.isNotEmpty) accountId = accounts.first.id;
                }
                if (accountId.isEmpty) {
                  if (context.mounted) Navigator.pop(context);
                  return;
                }

                // Generar transacción
                final isIncome = service.type == 'income';
                final notes = surcharge > 0 ? 'Monto original: \$${service.amount}. Recargo por mora: \$$surcharge' : null;
                
                await transactionsDao.createTransaction(
                  TransactionsCompanion.insert(
                    id: const Uuid().v4(),
                    amount: totalAmount,
                    date: DateTime.now(),
                    type: service.type,
                    accountId: accountId,
                    serviceId: drift.Value(service.id),
                    categoryId: drift.Value(service.categoryId),
                    description: drift.Value('Pago Manual: ${service.name}'),
                    notes: drift.Value(notes),
                    isRecurring: const drift.Value(true),
                  ),
                  accountId,
                  totalAmount,
                  isIncome,
                );

                // Calcular próxima fecha y restablecer estado a active.
                // 'once' retorna null: en ese caso no se reprograma, solo se mantiene
                // la fecha original al desactivar el servicio.
                final now = DateTime.now();
                final nextDate = ServiceScheduler.nextDateForService(service: service, now: now);
                if (nextDate != null) {
                  await servicesDao.updateService(
                    ServicesCompanion(
                      id: drift.Value(service.id),
                      nextDate: drift.Value(nextDate),
                      status: const drift.Value('active'),
                    ),
                  );
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Pagar'),
            ),
          ],
        );
      },
    );
  }

final servicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesDaoProvider).watchActiveServices();
});
