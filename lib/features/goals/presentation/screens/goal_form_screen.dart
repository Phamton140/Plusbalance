import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  final Goal? goal;

  const GoalFormScreen({super.key, this.goal});

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _amountController = TextEditingController(text: widget.goal?.targetAmount.toString() ?? '');
    _selectedDate = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el nombre y monto')));
      return;
    }

    final dao = ref.read(goalsDaoProvider);
    if (widget.goal == null) {
      await dao.createGoal(
        GoalsCompanion.insert(
          id: const Uuid().v4(),
          name: name,
          targetAmount: amount,
          targetDate: drift.Value(_selectedDate),
        )
      );
    } else {
      await dao.updateGoal(
        widget.goal!.copyWith(
          name: name,
          targetAmount: amount,
          targetDate: drift.Value(_selectedDate),
          updatedAt: DateTime.now(),
        )
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'Registrar Meta' : 'Editar Meta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Auto Nuevo'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto Objetivo',
                  hintText: '0.00',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha Límite (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _selectedDate == null ? 'Sin caducidad' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(color: _selectedDate == null ? Colors.grey : Theme.of(context).colorScheme.primary),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                    locale: const Locale('es'),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              if (_selectedDate != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedDate = null),
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  label: const Text('Quitar fecha límite', style: TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
