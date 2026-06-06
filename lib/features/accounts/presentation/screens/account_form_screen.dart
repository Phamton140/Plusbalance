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
  late TextEditingController _rechargeLabelController;
  late String _selectedColor;
  late String _rechargeFrequency;
  DateTime? _rechargeNextDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _bankController = TextEditingController(text: widget.account?.institutionName);
    _balanceController =
        TextEditingController(text: widget.account?.balance.toString() ?? '');
    _rechargeAmountController = TextEditingController(
        text: widget.account?.rechargeAmount?.toString() ?? '');
    _rechargeLabelController =
        TextEditingController(text: widget.account?.rechargeLabel ?? '');
    _selectedColor = widget.account?.color ?? '#1a1a2e';
    _rechargeFrequency = widget.account?.rechargeFrequency ?? 'none';
    _rechargeNextDate = widget.account?.rechargeNextDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    _rechargeAmountController.dispose();
    _rechargeLabelController.dispose();
    super.dispose();
  }

  /// Si el usuario eligió una frecuencia pero no una fecha, propone la
  /// próxima ocurrencia a partir de hoy.
  void _ensureDefaultNextDate() {
    if (_rechargeFrequency == 'none') {
      setState(() => _rechargeNextDate = null);
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
    setState(() => _rechargeNextDate = candidate);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final bank = _bankController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final rechargeAmount = double.tryParse(_rechargeAmountController.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El alias es obligatorio')));
      return;
    }

    final frequencyToSave =
        _rechargeFrequency == 'none' ? null : _rechargeFrequency;
    final rechargeLabel = _rechargeLabelController.text.trim().isEmpty
        ? null
        : _rechargeLabelController.text.trim();

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
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasRecharge = _rechargeFrequency != 'none';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Nueva Cuenta' : 'Editar Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(enableSuggestions: false, autocorrect: false,
                controller: _bankController,
                decoration: const InputDecoration(
                    labelText: 'Institución (Ej. Banco BHD)', hintText: 'Banco'),
              ),
              const SizedBox(height: 16),
              TextField(enableSuggestions: false, autocorrect: false,
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Alias (Ej. Tarjeta Gold)', hintText: 'Alias de cuenta'),
              ),
              const SizedBox(height: 16),
              TextField(enableSuggestions: false, autocorrect: false,
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onTap: () {
                  if (_balanceController.text.isNotEmpty) {
                    _balanceController.selection = TextSelection(
                        baseOffset: 0, extentOffset: _balanceController.text.length);
                  }
                },
                decoration: const InputDecoration(labelText: 'Saldo Inicial / Actual'),
              ),
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
                ],
              ),
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
                    } else {
                      _ensureDefaultNextDate();
                    }
                  });
                },
              ),
              if (hasRecharge) ...[
                const SizedBox(height: 16),
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
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _rechargeNextDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() => _rechargeNextDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(enableSuggestions: false, autocorrect: false,
                  controller: _rechargeLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Concepto (Ej. Salario)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(enableSuggestions: false, autocorrect: false,
                  controller: _rechargeAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto esperado (opcional)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
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
