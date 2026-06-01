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
  
  List<int> _selectedDays = [];

  final List<Map<String, dynamic>> _weekDays = [
    {'id': 1, 'name': 'L'},
    {'id': 2, 'name': 'M'},
    {'id': 3, 'name': 'M'},
    {'id': 4, 'name': 'J'},
    {'id': 5, 'name': 'V'},
    {'id': 6, 'name': 'S'},
    {'id': 7, 'name': 'D'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _amountController = TextEditingController(text: widget.service?.amount.toString() ?? '');
    _selectedType = widget.service?.type ?? 'expense';
    
    _selectedLabel = widget.service?.label ?? 'need';
    if (_selectedLabel == 'none') _selectedLabel = 'need'; // Migrate old data

    _autoPay = widget.service?.autoGenerateTransaction ?? true;
    _selectedDate = widget.service?.nextDate;
    _selectedCategoryId = widget.service?.categoryId;

    final freq = widget.service?.frequency ?? 'monthly';
    if (freq.startsWith('weekly:')) {
      _selectedFrequency = 'weekly';
      _selectedDays = freq.split(':')[1].split(',').map(int.parse).toList();
    } else {
      _selectedFrequency = freq;
    }
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

    if (_selectedFrequency == 'weekly' && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos un día para la frecuencia semanal')));
      return;
    }

    String finalFrequency = _selectedFrequency;
    if (_selectedFrequency == 'weekly' && _selectedDays.isNotEmpty) {
      _selectedDays.sort();
      finalFrequency = 'weekly:${_selectedDays.join(',')}';
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
          frequency: finalFrequency,
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
          frequency: finalFrequency,
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
              TextField(enableSuggestions: false, autocorrect: false, 
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej. Netflix / Salario'),
              ),
              const SizedBox(height: 16),
              TextField(enableSuggestions: false, autocorrect: false, 
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () {
                  if (_amountController.text.isNotEmpty) {
                    _amountController.selection = TextSelection(baseOffset: 0, extentOffset: _amountController.text.length);
                  }
                },
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
              if (_selectedFrequency == 'weekly') ...[
                const SizedBox(height: 16),
                const Text('Días de la semana', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _weekDays.map((d) {
                    final id = d['id'] as int;
                    final isSelected = _selectedDays.contains(id);
                    return ChoiceChip(
                      label: Text(d['name']),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(id);
                          } else {
                            _selectedDays.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                )
              ],
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final catsAsync = ref.watch(StreamProvider((ref) => ref.watch(categoriesDaoProvider).watchAllCategories()));
                  return catsAsync.when(
                    data: (cats) {
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
                title: const Text('Próxima Fecha de Pago/Cobro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _selectedDate == null ? 'Selecciona una fecha' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(color: _selectedDate == null ? Colors.red : Colors.grey),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
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
