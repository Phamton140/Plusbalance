import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

class GoalAddFundsScreen extends ConsumerStatefulWidget {
  final Goal goal;

  const GoalAddFundsScreen({super.key, required this.goal});

  @override
  ConsumerState<GoalAddFundsScreen> createState() => _GoalAddFundsScreenState();
}

class _GoalAddFundsScreenState extends ConsumerState<GoalAddFundsScreen> {
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido')));
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una cuenta')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(goalsDaoProvider).addFundsToGoal(
            goalId: widget.goal.id,
            accountId: _selectedAccountId!,
            amount: amount,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is StateError ? e.message : 'No se pudo registrar el abono')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Abonar a ${widget.goal.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Monto a abonar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
              ),
              const SizedBox(height: 24),
              const Text('Cuenta a debitar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No tienes cuentas activas. Crea una primero.', style: TextStyle(color: Colors.redAccent)),
                    );
                  }
                  if (_selectedAccountId == null && accounts.isNotEmpty) {
                    _selectedAccountId = accounts.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: accounts.any((a) => a.id == _selectedAccountId) ? _selectedAccountId : accounts.first.id,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: accounts.map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name}  ·  \$${a.balance.toStringAsFixed(2)}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: _saving ? null : (val) => setState(() => _selectedAccountId = val),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Este abono se registrará como un gasto en la categoría "Ahorro / Metas" para reflejar el débito de tu cuenta y sumarse al gráfico de gastos del dashboard.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Confirmar Abono', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
