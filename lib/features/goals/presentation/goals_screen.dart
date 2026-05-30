import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import 'screens/goal_form_screen.dart';

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
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Eliminar Meta"),
                        content: const Text("¿Estás seguro de que quieres eliminar esta meta? Todo el progreso registrado desaparecerá."),
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
                            Expanded(
                              child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                            ),
                            Row(
                              children: [
                                if (goal.targetDate != null)
                                  Text('Límite: ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => GoalFormScreen(goal: goal)));
                                  },
                                ),
                              ],
                            ),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalFormScreen()),
          );
        },
        icon: const Icon(Icons.flag),
        label: const Text('Nueva Meta'),
      ),
    );
  }
}

final activeGoalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchActiveGoals();
});
