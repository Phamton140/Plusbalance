import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsStream = ref.watch(activeGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      body: goalsStream.when(
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(child: Text('No hay metas activas.', style: TextStyle(color: Colors.white54)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progress = goal.currentAmount / goal.targetAmount;
              return Dismissible(
                key: Key(goal.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await (ref.read(databaseProvider).delete(ref.read(databaseProvider).goals)
                    ..where((g) => g.id.equals(goal.id)))
                    .go();
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            if (goal.targetDate != null)
                              Text('Límite: ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 8),
                        Text('\$${goal.currentAmount} / \$${goal.targetAmount}', style: const TextStyle(color: Colors.grey)),
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
        onPressed: () => _showCreateGoalDialog(context, ref),
        icon: const Icon(Icons.flag),
        label: const Text('Nueva Meta'),
      ),
    );
  }

  void _showCreateGoalDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Registrar Meta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Auto Nuevo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto Objetivo'),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha Límite (Opcional)', style: TextStyle(fontSize: 14)),
                      subtitle: Text(selectedDate == null ? 'Sin caducidad' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
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
                    
                    if (name.isNotEmpty && amount > 0) {
                      await ref.read(goalsDaoProvider).createGoal(
                        GoalsCompanion.insert(
                          id: const Uuid().v4(),
                          name: name,
                          targetAmount: amount,
                          targetDate: drift.Value(selectedDate),
                        )
                      );
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el nombre y monto')));
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

final activeGoalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchActiveGoals();
});
