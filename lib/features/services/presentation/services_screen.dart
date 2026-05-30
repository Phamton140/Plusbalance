import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

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
                      child: Icon(IconData(int.parse(service.icon), fontFamily: 'MaterialIcons'), color: Colors.white),
                    ),
                    title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${service.frequency.toUpperCase()} - Próximo cobro: ${service.nextDate.day}/${service.nextDate.month}/${service.nextDate.year}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        if (service.label != 'none')
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
                        if (service.autoGenerateTransaction)
                          const Icon(Icons.autorenew, size: 14, color: Colors.grey),
                      ],
                    ),
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
        onPressed: () => _showCreateServiceDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Registrar Servicio'),
      ),
    );
  }

  void _showCreateServiceDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedType = 'expense';
    String selectedFrequency = 'monthly';
    String selectedLabel = 'need';
    bool autoPay = true;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Registrar Servicio / Nómina'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Netflix / Salario'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'expense', child: Text('Gasto (Pago)')),
                        DropdownMenuItem(value: 'income', child: Text('Ingreso (Nómina)')),
                      ],
                      onChanged: (val) => setState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedLabel,
                      decoration: const InputDecoration(labelText: 'Etiqueta'),
                      items: const [
                        DropdownMenuItem(value: 'need', child: Text('Lo Necesito')),
                        DropdownMenuItem(value: 'want', child: Text('Lo Quiero')),
                        DropdownMenuItem(value: 'none', child: Text('Ninguna')),
                      ],
                      onChanged: (val) => setState(() => selectedLabel = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frecuencia'),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                        DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                        DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                        DropdownMenuItem(value: 'once', child: Text('Una vez')),
                      ],
                      onChanged: (val) => setState(() => selectedFrequency = val!),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Día de cobro', style: TextStyle(fontSize: 14)),
                      subtitle: Text(selectedDate == null ? 'Selecciona una fecha' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cobro/Ingreso Automático', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Se registrará solo en la fecha de corte', style: TextStyle(fontSize: 12)),
                      value: autoPay,
                      onChanged: (val) => setState(() => autoPay = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    
                    if (name.isNotEmpty && amount > 0 && selectedDate != null) {
                      await ref.read(servicesDaoProvider).createService(
                        ServicesCompanion.insert(
                          id: const Uuid().v4(),
                          name: name,
                          amount: amount,
                          type: drift.Value(selectedType),
                          label: drift.Value(selectedLabel),
                          frequency: selectedFrequency,
                          nextDate: selectedDate!,
                          autoGenerateTransaction: drift.Value(autoPay),
                        )
                      );
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos y la fecha')));
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

final servicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesDaoProvider).watchActiveServices();
});
