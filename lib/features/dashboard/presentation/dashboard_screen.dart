import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../transactions/presentation/screens/transaction_form_screen.dart';
import '../../services/providers/services_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/automation/automation_engine.dart';
import '../../../core/database/app_database.dart';
import '../../notifications/providers/recharge_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(automationEngineProvider);

    final totalBalanceAsync = ref.watch(totalBalanceProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);

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
                        ).animate().fadeIn().slideY(begin: 0.2),
                        loading: () => const Text("\$ --.--", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                        error: (e, s) => const Text("Error", style: TextStyle(fontSize: 36)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final lateList = ref.watch(lateServicesProvider).value ?? <Service>[];
                          final upcomingList = (ref.watch(upcomingServicesProvider).value ?? <Service>[]).where((s) => s.status != 'late').toList();
                          final rechargeList = ref.watch(upcomingAccountRechargesProvider).value ?? [];
                          final count = lateList.length + upcomingList.length + rechargeList.length;

                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, size: 28),
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
                      GestureDetector(
                        onTap: () => context.push('/profile').then((_) => ref.refresh(settingsDaoProvider)),
                        child: Consumer(
                          builder: (context, ref, child) {
                            final usernameAsync = ref.watch(_usernameProvider);
                            return Hero(
                              tag: 'avatar_profile',
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                child: usernameAsync.when(
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
                                    return CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFF6C63FF),
                                      child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                    );
                                  },
                                  loading: () => const CircularProgressIndicator(),
                                  error: (e, s) => const Icon(Icons.person),
                                ),
                              ),
                            );
                          }
                        ),
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
                        builder: (context, ref, child) {
                          final expensesAsync = ref.watch(expensesProvider);
                          final catsAsync = ref.watch(allCategoriesProvider);
                          
                          if (expensesAsync.isLoading || catsAsync.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final expenses = expensesAsync.value ?? [];
                          final categories = catsAsync.value ?? [];
                          
                          if (expenses.isEmpty) {
                            return const Center(child: Text('No hay gastos para graficar', style: TextStyle(color: Colors.grey)));
                          }
                          
                          return _ExpensePieChart(transactions: expenses, categories: categories);
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
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
    );
  }
}

class _ExpensePieChart extends StatefulWidget {
  final List<Transaction> transactions;
  final List<Category> categories;

  const _ExpensePieChart({required this.transactions, required this.categories});

  @override
  State<_ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<_ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Agrupar por categoría
    Map<String, double> sums = {};
    double total = 0;
    
    for (var tx in widget.transactions) {
      final catId = tx.categoryId ?? 'other';
      sums[catId] = (sums[catId] ?? 0) + tx.amount;
      total += tx.amount;
    }

    final entries = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    if (total == 0) return const SizedBox();

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
              sections: List.generate(entries.length, (i) {
                final isTouched = i == touchedIndex;
                final fontSize = isTouched ? 14.0 : 11.0;
                final radius = isTouched ? 60.0 : 50.0;
                final e = entries[i];
                final percentage = (e.value / total) * 100;

                Color color = Colors.grey;
                if (e.key != 'other') {
                  final cat = widget.categories.where((c) => c.id == e.key).firstOrNull;
                  if (cat != null) {
                    color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                  }
                }

                return PieChartSectionData(
                  color: color,
                  value: e.value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        ),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.take(4).map((e) {
              String name = 'Otros';
              Color color = Colors.grey;
              if (e.key != 'other') {
                final cat = widget.categories.where((c) => c.id == e.key).firstOrNull;
                if (cat != null) {
                  name = cat.name;
                  color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
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

final _usernameProvider = FutureProvider<String>((ref) async {
  final dao = ref.watch(settingsDaoProvider);
  final name = await dao.getSetting('profile_username');
  return name ?? 'Usuario +Balance';
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
