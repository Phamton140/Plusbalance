import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
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

final servicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesDaoProvider).watchActiveServices();
});
