import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../transactions/presentation/screens/transaction_form_screen.dart';
import '../../services/providers/services_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../notifications/providers/recharge_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalanceAsync = ref.watch(totalBalanceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Saldo Total",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      totalBalanceAsync.when(
                        data: (balance) => Text(
                          "\$ ${balance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        loading: () => const Text("\$ --.--", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                        error: (e, s) => const Text("Error", style: TextStyle(fontSize: 36)),
                      ),
                    ],
                  ),
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final count = ref.watch(notificationCountProvider);

                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_outlined, size: 28),
                                    tooltip: 'Notificaciones',
                                    onPressed: () => context.push('/notifications'),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(width: 8),
                          Consumer(
                            builder: (context, ref, _) {
                              final usernameAsync = ref.watch(_usernameProvider);
                              return usernameAsync.when(
                                data: (name) {
                                  String initials = "?";
                                  if (name.isNotEmpty) {
                                    final parts = name.split(" ").where((p) => p.isNotEmpty).toList();
                                    if (parts.length >= 2) {
                                      initials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
                                    } else {
                                      initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
                                    }
                                  }
                                  return InkWell(
                                    onTap: () => context.push('/profile').then((_) => ref.refresh(settingsDaoProvider)),
                                    borderRadius: BorderRadius.circular(24),
                                    child: Semantics(
                                      label: 'Perfil de usuario',
                                      button: true,
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: const Color(0xFF6C63FF),
                                        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                      ),
                                    ),
                                  );
                                },
                                loading: () => InkWell(
                                  onTap: () => context.push('/profile').then((_) => ref.refresh(settingsDaoProvider)),
                                  borderRadius: BorderRadius.circular(24),
                                  child: const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                error: (e, s) => InkWell(
                                  onTap: () => context.push('/profile').then((_) => ref.refresh(settingsDaoProvider)),
                                  borderRadius: BorderRadius.circular(24),
                                  child: const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Gráfico de Pastel (Distribución de Gastos)
                    Container(
                      height: 180,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final sectionsAsync = ref.watch(expenseDistributionProvider);
                          final legendAsync = ref.watch(pieChartLegendProvider);
                          
                          return sectionsAsync.when(
                            data: (sections) {
                              if (sections.isEmpty) {
                                return const Center(child: Text('No hay gastos para graficar', style: TextStyle(color: Colors.grey)));
                              }
                              return _ExpensePieChart(sections: sections, legend: legendAsync.value ?? []);
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Error: $e')),
                          );
                        }
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: _ModuleGrid(),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ExpensePieChart extends StatefulWidget {
  final List<PieChartSectionData> sections;
  final List<PieChartLegendEntry> legend;

  const _ExpensePieChart({required this.sections, required this.legend});

  @override
  State<_ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<_ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox();

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(widget.sections.length, (i) {
                final isTouched = i == touchedIndex;
                final section = widget.sections[i];
                return PieChartSectionData(
                  color: section.color,
                  value: section.value,
                  title: section.title,
                  radius: isTouched ? 60.0 : section.radius,
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 14.0 : section.titleStyle?.fontSize ?? 11.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.legend.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

final totalBalanceProvider = StreamProvider<double>((ref) {
  return ref.watch(accountsDaoProvider).watchTotalBalance();
});

final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionsDaoProvider).watchRecentTransactions(limit: 10);
});

final expensesProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)..where((t) => t.type.equals('expense'))).watch();
});

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesDaoProvider).watchAllCategories();
});

/// Computed expense distribution for pie chart (moved out of build for performance)
final expenseDistributionProvider = FutureProvider<List<PieChartSectionData>>((ref) async {
  final expenses = await ref.watch(expensesProvider.future);
  final categories = await ref.watch(allCategoriesProvider.future);

  if (expenses.isEmpty) return [];

  final categoryById = {for (var c in categories) c.id: c};
  final sums = <String, double>{};
  double total = 0;

  for (final tx in expenses) {
    final catId = tx.categoryId ?? 'other';
    sums[catId] = (sums[catId] ?? 0) + tx.amount;
    total += tx.amount;
  }

  if (total == 0) return [];

  final entries = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return entries.map((e) {
    final percentage = (e.value / total) * 100;

    Color color = Colors.grey;
    if (e.key != 'other') {
      final cat = categoryById[e.key];
      if (cat != null) {
        color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
      }
    }

    return PieChartSectionData(
      color: color,
      value: e.value,
      title: '${percentage.toStringAsFixed(0)}%',
      radius: 50.0,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }).toList();
});

/// Legend entries for pie chart
final pieChartLegendProvider = FutureProvider<List<PieChartLegendEntry>>((ref) async {
  final expenses = await ref.watch(expensesProvider.future);
  final categories = await ref.watch(allCategoriesProvider.future);

  if (expenses.isEmpty) return [];

  final categoryById = {for (var c in categories) c.id: c};
  final sums = <String, double>{};

  for (final tx in expenses) {
    final catId = tx.categoryId ?? 'other';
    sums[catId] = (sums[catId] ?? 0) + tx.amount;
  }

  final entries = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return entries.take(4).map((e) {
    String name = 'Otros';
    Color color = Colors.grey;
    if (e.key != 'other') {
      final cat = categoryById[e.key];
      if (cat != null) {
        name = cat.name;
        color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
      }
    }
    return PieChartLegendEntry(name: name, color: color);
  }).toList();
});

/// Simple data class for legend
class PieChartLegendEntry {
  final String name;
  final Color color;
  const PieChartLegendEntry({required this.name, required this.color});
}

final _usernameProvider = FutureProvider.autoDispose<String>((ref) async {
  final dao = ref.watch(settingsDaoProvider);
  final name = await dao.getSetting('profile_username');
  return name ?? 'Usuario +Balance';
});

final completableGoalsProvider = StreamProvider<List<Goal>>((ref) {
  return ref.watch(goalsDaoProvider).watchCompletableGoals();
});

final notificationCountProvider = Provider<int>((ref) {
  final lateList = ref.watch(lateServicesProvider).value ?? <Service>[];
  final upcomingList = (ref.watch(upcomingServicesProvider).value ?? <Service>[]).where((s) => s.status != 'late').toList();
  final rechargeList = ref.watch(upcomingAccountRechargesProvider).value ?? [];
  final completableGoals = ref.watch(completableGoalsProvider).value ?? [];
  return lateList.length + upcomingList.length + rechargeList.length + completableGoals.length;
});

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _ModuleCard(title: 'Cuentas', icon: Icons.credit_card, onTap: () => context.push('/accounts')),
        _ModuleCard(title: 'Servicios', icon: Icons.room_service, onTap: () => context.push('/services')),
        _ModuleCard(title: 'Metas', icon: Icons.track_changes, onTap: () => context.push('/goals')),
        _ModuleCard(title: 'Historial', icon: Icons.history, onTap: () => context.push('/transactions')),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
