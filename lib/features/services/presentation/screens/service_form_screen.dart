import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/automation/automation_engine.dart';

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
  DateTime? _selectedEndDate;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  
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
    _selectedEndDate = widget.service?.endDate;
    _selectedCategoryId = widget.service?.categoryId;
    _selectedAccountId = widget.service?.accountId;

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

    if (name.isEmpty || amount <= 0 || _selectedDate == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos, la fecha y la cuenta')));
      return;
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final selectedDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final tomorrowDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    if (selectedDay.isBefore(tomorrowDay)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La fecha debe ser futura (no se permiten hoy ni fechas pasadas)')));
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
          endDate: drift.Value(_selectedEndDate),
          accountId: drift.Value(_selectedAccountId),
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
          endDate: drift.Value(_selectedEndDate),
          accountId: drift.Value(_selectedAccountId),
          categoryId: drift.Value(_selectedCategoryId),
          autoGenerateTransaction: _autoPay,
          updatedAt: DateTime.now(),
        )
      );
    }
    
    // Forzar ejecución del motor de automatización para evaluar servicios recién registrados o editados
    ref.invalidate(automationEngineProvider);
    
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
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  hintText: '0.00',
                  prefixText: '\$ ',
                ),
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
                      showCheckmark: false,
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
                builder: (context, ref, _) {
                  final accountsAsync = ref.watch(_activeAccountsProvider);
                  return accountsAsync.when(
                    data: (accounts) {
                      final validAccId = accounts.any((a) => a.id == _selectedAccountId) ? _selectedAccountId : null;
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: validAccId,
                        decoration: const InputDecoration(labelText: 'Cuenta de Cargo/Abono'),
                        items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedAccountId = val),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, __) => Text('Error: $e'),
                  );
                }
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final catsAsync = ref.watch(_categoriesProvider);
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
                    loading: () => const CircularProgressIndicator(),
                    error: (e, __) => Text('Error: $e'),
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
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate != null && _selectedDate!.isAfter(tomorrow)
                        ? _selectedDate!
                        : tomorrow,
                    firstDate: tomorrow,
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    helpText: 'Selecciona una fecha futura',
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              if (_selectedFrequency != 'once') ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha Fin de Recurrencia (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _selectedEndDate == null ? 'Sin fecha límite' : '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}',
                    style: TextStyle(color: _selectedEndDate == null ? Colors.grey : Theme.of(context).colorScheme.primary),
                  ),
                  trailing: const Icon(Icons.event_busy),
                  onTap: () async {
                    final minDate = _selectedDate ?? DateTime.now().add(const Duration(days: 1));
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedEndDate ?? minDate,
                      firstDate: minDate,
                      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      helpText: 'Selecciona fecha de finalización',
                    );
                    if (date != null) {
                      setState(() => _selectedEndDate = date);
                    }
                  },
                ),
                if (_selectedEndDate != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedEndDate = null),
                    icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                    label: const Text('Quitar fecha fin', style: TextStyle(color: Colors.red)),
                  ),
              ],
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

final _activeAccountsProvider = StreamProvider((ref) {
  return ref.watch(accountsDaoProvider).watchActiveAccounts();
});

final _categoriesProvider = StreamProvider((ref) {
  return ref.watch(categoriesDaoProvider).watchAllCategories().map((cats) => 
    cats.where((c) => c.id != goalDefaultCategoryId).toList()
  );
});
