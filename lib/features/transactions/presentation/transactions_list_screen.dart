import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/services/pdf_service.dart';

class TransactionFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String value) {
    state = value;
  }
}

final transactionFilterProvider = NotifierProvider<TransactionFilterNotifier, String>(() {
  return TransactionFilterNotifier();
});

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider(filter));
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Transacciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar Reporte',
            onPressed: () async {
              final DateTimeRange? pickedRange = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                helpText: 'Rango del Reporte (Deja vacío para TODO)',
                cancelText: 'TODO EL HISTORIAL',
                confirmText: 'GENERAR',
              );

              try {
                // Obtain data
                final db = ref.read(databaseProvider);
                List<Transaction> txs;
                if (pickedRange != null) {
                  // El selector devuelve el final con hora 00:00, lo extendemos
                  // al final del día para que las transacciones del último día
                  // seleccionado sí se incluyan.
                  final endOfDay = DateTime(
                    pickedRange.end.year,
                    pickedRange.end.month,
                    pickedRange.end.day,
                    23, 59, 59, 999,
                  );
                  txs = await (db.select(db.transactions)
                    ..where((t) => t.date.isBetweenValues(pickedRange.start, endOfDay))
                    ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc)])
                  ).get();
                } else {
                  txs = await (db.select(db.transactions)
                    ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc)])
                  ).get();
                }
                final accounts = await db.select(db.accounts).get();
                final categories = await db.select(db.categories).get();
                final userName = await ref.read(settingsDaoProvider).getSetting('profile_username');

                await PdfService.generateAndPrintTransactionsReport(
                  transactions: txs,
                  accounts: accounts,
                  categories: categories,
                  startDate: pickedRange?.start,
                  endDate: pickedRange?.end,
                  userName: userName,
                );
              } catch (e, st) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo generar el PDF: $e'),
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
                // ignore: avoid_print
                debugPrint('PDF error: $e\n$st');
              }
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _FilterChip(title: 'Todos', value: 'all', groupValue: filter),
                const SizedBox(width: 8),
                _FilterChip(title: 'Ingresos', value: 'income', groupValue: filter),
                const SizedBox(width: 8),
                _FilterChip(title: 'Gastos', value: 'expense', groupValue: filter),
              ],
            ),
          ),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'No hay transacciones registradas.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isIncome = tx.type == 'income';
              
              return Dismissible(
                key: Key(tx.id),
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
                        title: const Text("Confirmar Eliminación"),
                        content: const Text("¿Estás seguro que deseas eliminar esta transacción? Tu saldo será revertido."),
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
                  await ref.read(transactionsDaoProvider).deleteTransactionAndRevertBalance(tx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transacción eliminada y balance revertido')),
                    );
                  }
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIncome ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      child: Icon(
                        isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isIncome ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    title: Text(tx.description ?? (isIncome ? 'Ingreso' : 'Gasto'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(dateFormat.format(tx.date), style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 16,
                        color: isIncome ? Colors.green : Colors.redAccent,
                      ),
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
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String title;
  final String value;
  final String groupValue;

  const _FilterChip({required this.title, required this.value, required this.groupValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(transactionFilterProvider.notifier).setFilter(value);
        }
      },
    );
  }
}

final filteredTransactionsProvider = StreamProvider.family<List<Transaction>, String>((ref, filter) {
  final dao = ref.watch(transactionsDaoProvider);
  if (filter == 'all') {
    return dao.watchRecentTransactions(limit: 500); // 500 límite MVP
  } else {
    return dao.watchTransactionsByType(filter, limit: 500);
  }
});
