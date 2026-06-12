import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import 'screens/goal_form_screen.dart';
import 'screens/goal_add_funds_screen.dart';

/// Shared provider for alcancia balance to avoid multiple subscriptions
final alcanciaBalanceProvider = StreamProvider.autoDispose<Account?>((ref) {
  return ref.watch(goalsDaoProvider).watchAlcanciaBalance();
});

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsStream = ref.watch(activeGoalsProvider);
    final alcanciaAsync = ref.watch(alcanciaBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas de Ahorro')),
      body: goalsStream.when(
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(child: Text('No hay metas activas.', style: TextStyle(color: Colors.white54)));
          }
          return Column(
            children: [
              alcanciaAsync.when(
                data: (alcancia) {
                  final balance = alcancia?.balance ?? 0.0;
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade700, Colors.amber.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings, color: Colors.white, size: 48),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('En Alcancía', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(
                                '\$${balance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.white),
                          tooltip: 'Enviar a Alcancía',
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalAddFundsScreen()));
                          },
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(height: 120, child: Center(child: Text('Error cargando balance', style: TextStyle(color: Colors.white54)))),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return RepaintBoundary(
                      child: _GoalCard(goal: goal),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalFormScreen()));
        },
        icon: const Icon(Icons.flag),
        label: const Text('Nueva Meta'),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final Goal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alcanciaAsync = ref.watch(alcanciaBalanceProvider);
    return alcanciaAsync.when(
      data: (alcancia) {
        final alcanciaBalance = alcancia?.balance ?? 0.0;
        final effectiveAmount = alcanciaBalance.clamp(0.0, goal.targetAmount);
        final progress = goal.targetAmount > 0 ? effectiveAmount / goal.targetAmount : 0.0;
        final isCompletable = alcanciaBalance >= goal.targetAmount;

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
              builder: (context) => AlertDialog(
                title: const Text("Eliminar Meta"),
                content: const Text("¿Estás seguro de que quieres eliminar esta meta?"),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text("Eliminar")
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            final db = ref.read(databaseProvider);
            await (db.delete(db.goals)..where((g) => g.id.equals(goal.id))).go();
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                            if (goal.targetDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Límite: ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Editar meta',
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => GoalFormScreen(goal: goal)));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompletable ? Colors.green : Color.lerp(Colors.grey.shade500, Colors.green, progress.clamp(0.0, 1.0))!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${effectiveAmount.toStringAsFixed(2)} / \$${goal.targetAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      if (isCompletable)
                        ElevatedButton.icon(
                          onPressed: () => _completeGoal(context, ref),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Completar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                    ],
                  ),
                  if (isCompletable)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('¡Ya puedes completar esta meta!', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(margin: EdgeInsets.only(bottom: 12), child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))),
      error: (_, __) => const Card(margin: EdgeInsets.only(bottom: 12), child: SizedBox(height: 100, child: Center(child: Text('Error', style: TextStyle(color: Colors.white54))))),
    );
  }

  Future<void> _completeGoal(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Completar "${goal.name}"?'),
        content: Text('Se debitara \$${goal.targetAmount.toStringAsFixed(2)} de la Alcancía y se registrara como un gasto.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completar')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(goalsDaoProvider).completeGoal(goalId: goal.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Meta "${goal.name}" completada!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is StateError ? e.message : 'Error al completar meta')));
      }
    }
  }
}

final activeGoalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchActiveGoals();
});