import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../transactions/presentation/widgets/quick_record_bottom_sheet.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/automation/automation_engine.dart';
import '../../../core/database/app_database.dart';

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
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: const CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Gráfico de líneas (Evolución)
                    Container(
                      height: 200,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: transactionsAsync.when(
                        data: (txs) {
                          if (txs.isEmpty) return const Center(child: Text('No hay datos para graficar', style: TextStyle(color: Colors.grey)));
                          return _BalanceLineChart(transactions: txs);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: 32),
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
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const QuickRecordBottomSheet(),
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

class _BalanceLineChart extends StatelessWidget {
  final List<Transaction> transactions;

  const _BalanceLineChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Generar datos ficticios basados en transacciones recientes para el gráfico de líneas
    // En producción, esto calcularía el saldo en el tiempo
    final spots = <FlSpot>[];
    double currentBal = 0;
    
    // Invertimos porque vienen de más reciente a más antiguo
    final reversedTxs = transactions.reversed.toList();
    for (int i = 0; i < reversedTxs.length; i++) {
      final tx = reversedTxs[i];
      if (tx.type == 'income') {
        currentBal += tx.amount;
      } else if (tx.type == 'expense') {
        currentBal -= tx.amount;
      }
      spots.add(FlSpot(i.toDouble(), currentBal));
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }
    if (spots.length == 1) {
      spots.add(FlSpot(1, spots.first.y));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }
}

final totalBalanceProvider = StreamProvider<double>((ref) {
  return ref.watch(accountsDaoProvider).watchTotalBalance();
});

final recentTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionsDaoProvider).watchRecentTransactions(limit: 10);
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
