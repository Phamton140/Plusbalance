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
                locale: const Locale('es'),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: _FilterChip(title: 'Todos', value: 'all', groupValue: filter),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: _FilterChip(title: 'Ingresos', value: 'income', groupValue: filter),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: _FilterChip(title: 'Gastos', value: 'expense', groupValue: filter),
                ),
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
          // Agrupamos por día para mostrar un encabezado por fecha y
          // que el usuario pueda ir viendo el histórico organizado al
          // hacer scroll. Como la lista ya viene ordenada por fecha
          // descendente, basta con detectar cambios de día.
          final dayHeaderFmt = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es');
          // Si la localización 'es' no está inicializada, caemos a un
          // formato manual largo.
          String manualDayHeader(DateTime d) {
            const meses = [
              'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
              'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
            ];
            const dias = [
              'Lunes', 'Martes', 'Miércoles', 'Jueves',
              'Viernes', 'Sábado', 'Domingo'
            ];
            return '${dias[d.weekday - 1]} ${d.day} de ${meses[d.month - 1]}, ${d.year}';
          }

          final items = <_HistoryItem>[];
          DateTime? lastDay;
          for (final tx in transactions) {
            final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
            if (lastDay == null || d != lastDay) {
              String header;
              try {
                header = dayHeaderFmt.format(d);
              } catch (_) {
                header = manualDayHeader(d);
              }
              items.add(_HistoryItem.header(header));
              lastDay = d;
            }
            items.add(_HistoryItem.tx(tx));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.header != null) {
                return Padding(
                  padding: EdgeInsets.only(
                      top: index == 0 ? 0 : 12, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.header!,
                          style: const TextStyle(
                            color: Colors.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final tx = item.tx!;
              final isIncome = tx.type == 'income';
              final isTransfer = tx.type == 'transfer';

              return Dismissible(
                key: Key(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Revertir',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                confirmDismiss: (direction) =>
                    _confirmReverse(context, ref, tx),
                onDismissed: (direction) async {
                  await _performReverse(context, ref, tx);
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIncome
                          ? Colors.green.withValues(alpha: 0.2)
                          : isTransfer
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                      child: Icon(
                        isIncome
                            ? Icons.arrow_upward
                            : isTransfer
                                ? Icons.sync_alt
                                : Icons.arrow_downward,
                        color: isIncome
                            ? Colors.green
                            : isTransfer
                                ? Colors.blue
                                : Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      tx.description ??
                          (isTransfer
                              ? 'Transferencia'
                              : isIncome
                                  ? 'Ingreso'
                                  : 'Gasto'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('HH:mm').format(tx.date),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isTransfer
                              ? '\$${tx.amount.toStringAsFixed(2)}'
                              : '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isIncome
                                ? Colors.green
                                : isTransfer
                                    ? Colors.blue
                                    : Colors.redAccent,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Más acciones',
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            if (value == 'reverse') {
                              _confirmAndReverse(context, ref, tx);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'reverse',
                              child: Row(
                                children: [
                                  Icon(Icons.undo, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Revertir'),
                                ],
                              ),
                            ),
                          ],
                        ),
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

/// Item intermedio para la lista del historial: o es un encabezado de
/// día o es la tarjeta de una transacción. Permite renderizar un
/// ListView plano agrupado por fecha.
class _HistoryItem {
  final String? header;
  final Transaction? tx;
  const _HistoryItem.header(this.header) : tx = null;
  const _HistoryItem.tx(this.tx) : header = null;
}

/// Muestra un diálogo de confirmación y, si el usuario acepta, ejecuta
/// la reversión de la transacción. Usado por el `PopupMenuButton`.
Future<void> _confirmAndReverse(
    BuildContext context, WidgetRef ref, Transaction tx) async {
  final ok = await _confirmReverse(context, ref, tx);
  if (ok == true) {
    await _performReverse(context, ref, tx);
  }
}

/// Diálogo de confirmación para revertir una transacción. Devuelve `true`
/// si el usuario aceptó.
Future<bool?> _confirmReverse(
    BuildContext context, WidgetRef ref, Transaction tx) async {
  final isTransfer = tx.type == 'transfer';
  final isIncome = tx.type == 'income';
  final sign = isIncome ? '+' : '-';
  final detail = isTransfer
      ? 'Esta transferencia se compone de dos movimientos (origen y destino). Se restaurará el saldo en ambas cuentas.'
      : 'El saldo de la cuenta se ${isIncome ? 'descontará' : 'devolverá'} y la transacción se eliminará del historial.';
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('¿Revertir esta transacción?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx.description ?? 'Transacción',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$sign\$${tx.amount.toStringAsFixed(2)} · ${DateFormat('dd/MM/yyyy HH:mm').format(tx.date)}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(detail, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Revertir'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
}

/// Ejecuta la reversión y muestra feedback al usuario (SnackBar o error).
Future<void> _performReverse(
    BuildContext context, WidgetRef ref, Transaction tx) async {
  try {
    if (tx.sourceType == 'goal') {
      await ref.read(goalsDaoProvider).reverseGoalContribution(
            transactionId: tx.id,
          );
    } else {
      await ref.read(transactionsDaoProvider).reverseTransaction(tx);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Transacción revertida y saldo restaurado'),
            backgroundColor: Colors.orange),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No se pudo revertir: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}
