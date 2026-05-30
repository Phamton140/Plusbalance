import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

class ServiceFormScreen extends ConsumerStatefulWidget {
  final Service? service;

  const ServiceFormScreen({super.key, this.service});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late String _selectedType;
  late String _selectedFrequency;
  late String _selectedLabel;
  late bool _autoPay;
  DateTime? _selectedDate;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _amountController = TextEditingController(text: widget.service?.amount.toString() ?? '');
    _selectedType = widget.service?.type ?? 'expense';
    _selectedFrequency = widget.service?.frequency ?? 'monthly';
    _selectedLabel = widget.service?.label ?? 'need';
    _autoPay = widget.service?.autoGenerateTransaction ?? true;
    _selectedDate = widget.service?.nextDate;
    _selectedCategoryId = widget.service?.categoryId;
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
    
    if (name.isEmpty || amount <= 0 || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos y la fecha')));
      return;
    }

    final dao = ref.read(servicesDaoProvider);
    if (widget.service == null) {
      await dao.createService(
        ServicesCompanion.insert(
          id: const Uuid().v4(),
          name: name,
          amount: amount,
          type: drift.Value(_selectedType),
          label: drift.Value(_selectedLabel),
          frequency: _selectedFrequency,
          nextDate: _selectedDate!,
          categoryId: drift.Value(_selectedCategoryId),
          autoGenerateTransaction: drift.Value(_autoPay),
        )
      );
    } else {
      await dao.updateService(
        widget.service!.copyWith(
          name: name,
          amount: amount,
          type: _selectedType,
          label: _selectedLabel,
          frequency: _selectedFrequency,
          nextDate: _selectedDate!,
          categoryId: drift.Value(_selectedCategoryId),
          autoGenerateTransaction: _autoPay,
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
        title: Text(widget.service == null ? 'Registrar Servicio / Nómina' : 'Editar Servicio'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Netflix / Salario'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Gasto (Pago)')),
                  DropdownMenuItem(value: 'income', child: Text('Ingreso (Nómina)')),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLabel,
                decoration: const InputDecoration(labelText: 'Etiqueta'),
                items: const [
                  DropdownMenuItem(value: 'need', child: Text('Lo Necesito')),
                  DropdownMenuItem(value: 'want', child: Text('Lo Quiero')),
                  DropdownMenuItem(value: 'none', child: Text('Ninguna')),
                ],
                onChanged: (val) => setState(() => _selectedLabel = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                  DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                  DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                  DropdownMenuItem(value: 'once', child: Text('Una vez')),
                ],
                onChanged: (val) => setState(() => _selectedFrequency = val!),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final catsAsync = ref.watch(StreamProvider((ref) => ref.watch(categoriesDaoProvider).watchAllCategories()));
                  return catsAsync.when(
                    data: (cats) {
                      // Validate if selected category still exists
                      final validCatId = cats.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null;
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: validCatId,
                        decoration: const InputDecoration(labelText: 'Categoría (Opcional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Ninguna')),
                          ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  );
                }
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Próxima Fecha / Día de cobro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _selectedDate == null ? 'Selecciona una fecha' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(color: _selectedDate == null ? Colors.red : Colors.grey),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow slightly past dates for edits
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cobro/Ingreso Automático', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: const Text('Se registrará solo en la fecha programada', style: TextStyle(fontSize: 12)),
                value: _autoPay,
                onChanged: (val) => setState(() => _autoPay = val),
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
