import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/account_constants.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bankController;
  late TextEditingController _balanceController;
  late TextEditingController _rechargeAmountController;
  late TextEditingController _rechargeAmountController2;
  late TextEditingController _rechargeLabelController;
  late String _selectedColor;
  late String _rechargeFrequency;
  DateTime? _rechargeNextDate;
  DateTime? _rechargeNextDate2;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _bankController = TextEditingController(text: widget.account?.institutionName);
    _balanceController =
        TextEditingController(text: widget.account?.balance.toString() ?? '');
    _rechargeAmountController = TextEditingController(
        text: widget.account?.rechargeAmount?.toString() ?? '');
    _rechargeAmountController2 = TextEditingController(
        text: widget.account?.rechargeAmount2?.toString() ?? '');
    _rechargeLabelController =
        TextEditingController(text: widget.account?.rechargeLabel ?? '');
    _selectedColor = widget.account?.color ?? '#1a1a2e';
    _rechargeFrequency = widget.account?.rechargeFrequency ?? 'none';
    _rechargeNextDate = widget.account?.rechargeNextDate;
    _rechargeNextDate2 = widget.account?.rechargeNextDate2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    _rechargeAmountController.dispose();
    _rechargeAmountController2.dispose();
    _rechargeLabelController.dispose();
    super.dispose();
  }

  /// Si el usuario eligió una frecuencia pero no una fecha, propone la
  /// próxima ocurrencia a partir de hoy.
  void _ensureDefaultNextDate() {
    if (_rechargeFrequency == 'none') {
      setState(() {
        _rechargeNextDate = null;
        _rechargeNextDate2 = null;
      });
      return;
    }
    if (_rechargeNextDate != null) return;
    final now = DateTime.now();
    DateTime candidate;
    switch (_rechargeFrequency) {
      case 'weekly':
        candidate = now.add(const Duration(days: 7));
        break;
      case 'biweekly':
        candidate = now.add(const Duration(days: 14));
        break;
      case 'monthly':
        candidate = DateTime(now.year, now.month + 1, now.day);
        break;
      default:
        return;
    }
    setState(() {
      _rechargeNextDate = candidate;
      // Para quincenal, sugerir la segunda fecha 14 días después.
      if (_rechargeFrequency == 'biweekly') {
        _rechargeNextDate2 = candidate.add(const Duration(days: 14));
      }
    });
  }

  Future<void> _save() async {
    final isLocked = _isEfectivoDefault;
    final name = isLocked ? 'Efectivo' : _nameController.text.trim();
    final bank = isLocked ? 'Efectivo' : _bankController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final rechargeAmount = double.tryParse(_rechargeAmountController.text);
    final rechargeAmount2 = double.tryParse(_rechargeAmountController2.text);

    if (!isLocked && name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El alias es obligatorio')));
      return;
    }

    final isBiweekly = _rechargeFrequency == 'biweekly';
    final frequencyToSave =
        _rechargeFrequency == 'none' ? null : _rechargeFrequency;
    final rechargeLabel = _rechargeLabelController.text.trim().isEmpty
        ? null
        : _rechargeLabelController.text.trim();

    // Para quincenal, exigir AMBAS fechas; para otras, sólo la primera.
    if (frequencyToSave != null) {
      if (isBiweekly) {
        if (_rechargeNextDate == null || _rechargeNextDate2 == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Quincenal requiere las dos fechas de pago del mes')));
          return;
        }
      } else if (_rechargeNextDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Indica la próxima fecha de recarga')));
        return;
      }
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      bool isPast(DateTime? d) {
        if (d == null) return false;
        final dd = DateTime(d.year, d.month, d.day);
        final t = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        return dd.isBefore(t);
      }

      if (isPast(_rechargeNextDate) || (isBiweekly && isPast(_rechargeNextDate2))) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Las fechas de recarga deben ser futuras')));
        return;
      }
    }

    if (widget.account == null) {
      await ref.read(accountsDaoProvider).createAccount(
        AccountsCompanion.insert(
          id: const Uuid().v4(),
          name: name,
          type: 'bank',
          balance: drift.Value(balance),
          institutionName: drift.Value(bank),
          color: drift.Value(_selectedColor),
          rechargeFrequency: drift.Value(frequencyToSave),
          rechargeNextDate: drift.Value(_rechargeNextDate),
          rechargeAmount: drift.Value(rechargeAmount),
          rechargeLabel: drift.Value(rechargeLabel),
          rechargeNextDate2: drift.Value(isBiweekly ? _rechargeNextDate2 : null),
          rechargeAmount2: drift.Value(isBiweekly ? rechargeAmount2 : null),
        ),
      );
    } else {
      await ref.read(accountsDaoProvider).updateAccount(
        Account(
          id: widget.account!.id,
          name: name,
          type: widget.account!.type,
          balance: balance,
          institutionName: bank,
          color: _selectedColor,
          creditLimit: widget.account!.creditLimit,
          cutDay: widget.account!.cutDay,
          paymentDay: widget.account!.paymentDay,
          interestRate: widget.account!.interestRate,
          isArchived: widget.account!.isArchived,
          createdAt: widget.account!.createdAt,
          updatedAt: DateTime.now(),
          currency: widget.account!.currency,
          rechargeFrequency: frequencyToSave,
          rechargeNextDate: _rechargeNextDate,
          rechargeAmount: rechargeAmount,
          rechargeLabel: rechargeLabel,
          rechargeNextDate2: isBiweekly ? _rechargeNextDate2 : null,
          rechargeAmount2: isBiweekly ? rechargeAmount2 : null,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  bool get _isEfectivoDefault =>
      widget.account?.id == efectivoDefaultAccountId;

  @override
  Widget build(BuildContext context) {
    final hasRecharge = _rechargeFrequency != 'none';
    final isLocked = _isEfectivoDefault;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null
            ? 'Nueva Cuenta'
            : isLocked
                ? 'Efectivo'
                : 'Editar Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.teal),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La cuenta de efectivo es única y predeterminada. '
                          'Solo puedes modificar su saldo y la recurrencia de recarga.',
                          style: TextStyle(fontSize: 12, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                TextField(
                  controller: _bankController,
                  decoration: const InputDecoration(
                      labelText: 'Institución (Ej. Banco BHD)', hintText: 'Banco'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Alias (Ej. Tarjeta Gold)', hintText: 'Alias de cuenta'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saldo Inicial / Actual',
                  hintText: '0.00',
                  prefixText: '\$ ',
                ),
              ),
              if (!isLocked) ...[
                const SizedBox(height: 24),
                const Text('Color de la tarjeta:',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ColorPickerOption(
                        colorHex: '#1a1a2e',
                        isSelected: _selectedColor == '#1a1a2e',
                        onTap: () => setState(() => _selectedColor = '#1a1a2e')),
                    _ColorPickerOption(
                        colorHex: '#C5A866',
                        isSelected: _selectedColor == '#C5A866',
                        onTap: () => setState(() => _selectedColor = '#C5A866')),
                    _ColorPickerOption(
                        colorHex: '#2E7D32',
                        isSelected: _selectedColor == '#2E7D32',
                        onTap: () => setState(() => _selectedColor = '#2E7D32')),
                    _ColorPickerOption(
                        colorHex: '#1565C0',
                        isSelected: _selectedColor == '#1565C0',
                        onTap: () => setState(() => _selectedColor = '#1565C0')),
                    _ColorPickerOption(
                        colorHex: '#D32F2F',
                        isSelected: _selectedColor == '#D32F2F',
                        onTap: () => setState(() => _selectedColor = '#D32F2F')),
                    _ColorPickerOption(
                        colorHex: '#8E24AA',
                        isSelected: _selectedColor == '#8E24AA',
                        onTap: () => setState(() => _selectedColor = '#8E24AA')),
                    _ColorPickerOption(
                        colorHex: '#6B7280',
                        isSelected: _selectedColor == '#6B7280',
                        onTap: () => setState(() => _selectedColor = '#6B7280')),
                    _ColorPickerOption(
                        colorHex: '#78716C',
                        isSelected: _selectedColor == '#78716C',
                        onTap: () => setState(() => _selectedColor = '#78716C')),
                    _ColorPickerOption(
                        colorHex: '#7B8794',
                        isSelected: _selectedColor == '#7B8794',
                        onTap: () => setState(() => _selectedColor = '#7B8794')),
                    _ColorPickerOption(
                        colorHex: '#6B8E7B',
                        isSelected: _selectedColor == '#6B8E7B',
                        onTap: () => setState(() => _selectedColor = '#6B8E7B')),
                    _ColorPickerOption(
                        colorHex: '#8B7355',
                        isSelected: _selectedColor == '#8B7355',
                        onTap: () => setState(() => _selectedColor = '#8B7355')),
                  ],
                ),
              ],
              const SizedBox(height: 32),

              // -------- Sección de Recurrencia de Recarga (opcional) --------
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.autorenew, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Recurrencia de Recarga (opcional)',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Si te acreditan dinero con una frecuencia predecible (ej. salario), '
                'configúralo aquí para que la app te avise antes de cada recarga.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _rechargeFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia',
                  border: OutlineInputBorder(),
                ),
                items: kRechargeFrequencyLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _rechargeFrequency = val;
                    if (val == 'none') {
                      _rechargeNextDate = null;
                      _rechargeNextDate2 = null;
                    } else if (val != 'biweekly') {
                      // Si cambia de quincenal a otra, limpiamos la 2da.
                      _rechargeNextDate2 = null;
                      _rechargeAmountController2.clear();
                      _ensureDefaultNextDate();
                    } else {
                      _ensureDefaultNextDate();
                    }
                  });
                },
              ),
              if (hasRecharge) ...[
                const SizedBox(height: 16),
                if (_rechargeFrequency == 'biweekly') ...[
                  const Text(
                    'Selecciona las DOS fechas de pago del mes',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.teal),
                    title: const Text('1ra fecha de pago'),
                    subtitle: Text(
                      _rechargeNextDate == null
                          ? 'Toca para elegir'
                          : '${_rechargeNextDate!.day}/${_rechargeNextDate!.month}/${_rechargeNextDate!.year}',
                      style: TextStyle(
                        color: _rechargeNextDate == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final tomorrow = DateTime.now().add(const Duration(days: 1));
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _rechargeNextDate != null && _rechargeNextDate!.isAfter(tomorrow)
                            ? _rechargeNextDate!
                            : tomorrow,
                        firstDate: tomorrow,
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 5)),
                        helpText: 'Selecciona una fecha futura',
                      );
                      if (picked != null) {
                        setState(() {
                          _rechargeNextDate = picked;
                          // Si aún no se ha elegido la 2da, sugerir +14d.
                          if (_rechargeNextDate2 == null) {
                            _rechargeNextDate2 =
                                picked.add(const Duration(days: 14));
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.teal),
                    title: const Text('2da fecha de pago'),
                    subtitle: Text(
                      _rechargeNextDate2 == null
                          ? 'Toca para elegir'
                          : '${_rechargeNextDate2!.day}/${_rechargeNextDate2!.month}/${_rechargeNextDate2!.year}',
                      style: TextStyle(
                        color: _rechargeNextDate2 == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final tomorrow = DateTime.now().add(const Duration(days: 1));
                      final defaultInit = _rechargeNextDate2 ??
                          (_rechargeNextDate ?? DateTime.now())
                              .add(const Duration(days: 14));
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: defaultInit.isAfter(tomorrow) ? defaultInit : tomorrow,
                        firstDate: tomorrow,
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 5)),
                        helpText: 'Selecciona una fecha futura',
                      );
                      if (picked != null) {
                        setState(() => _rechargeNextDate2 = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rechargeLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Concepto (Ej. Salario)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rechargeAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto 1ra recarga (opcional)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rechargeAmountController2,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto 2da recarga (opcional)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Próxima fecha de recarga'),
                    subtitle: Text(
                      _rechargeNextDate == null
                          ? 'Toca para elegir'
                          : '${_rechargeNextDate!.day}/${_rechargeNextDate!.month}/${_rechargeNextDate!.year}',
                      style: TextStyle(
                        color: _rechargeNextDate == null
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final tomorrow = DateTime.now().add(const Duration(days: 1));
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _rechargeNextDate != null && _rechargeNextDate!.isAfter(tomorrow)
                            ? _rechargeNextDate!
                            : tomorrow,
                        firstDate: tomorrow,
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                        helpText: 'Selecciona una fecha futura',
                      );
                      if (picked != null) {
                        setState(() => _rechargeNextDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rechargeLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Concepto (Ej. Salario)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rechargeAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto esperado (opcional)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
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
                  child: const Text('Guardar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerOption extends StatelessWidget {
  final String colorHex;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorPickerOption({
    required this.colorHex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Color(int.parse(colorHex.replaceAll('#', '0xFF')))
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Color(int.parse(colorHex.replaceAll('#', '0xFF'))),
          child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
        ),
      ),
    );
  }
}
