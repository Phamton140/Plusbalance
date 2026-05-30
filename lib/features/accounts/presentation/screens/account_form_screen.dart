import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/app_database.dart';

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
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name);
    _bankController = TextEditingController(text: widget.account?.institutionName);
    _balanceController = TextEditingController(text: widget.account?.balance.toString() ?? '');
    _selectedColor = widget.account?.color ?? '#1a1a2e';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final bank = _bankController.text.trim();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El alias es obligatorio')));
      return;
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
        )
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
        )
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              TextField(
                controller: _bankController,
                decoration: const InputDecoration(labelText: 'Institución (Ej. Banco BHD)', hintText: 'Banco'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Alias (Ej. Tarjeta Gold)', hintText: 'Alias de cuenta'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Saldo Inicial / Actual'),
              ),
              const SizedBox(height: 24),
              const Text('Color de la tarjeta:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ColorPickerOption(colorHex: '#1a1a2e', isSelected: _selectedColor == '#1a1a2e', onTap: () => setState(() => _selectedColor = '#1a1a2e')),
                  _ColorPickerOption(colorHex: '#C5A866', isSelected: _selectedColor == '#C5A866', onTap: () => setState(() => _selectedColor = '#C5A866')),
                  _ColorPickerOption(colorHex: '#2E7D32', isSelected: _selectedColor == '#2E7D32', onTap: () => setState(() => _selectedColor = '#2E7D32')),
                  _ColorPickerOption(colorHex: '#1565C0', isSelected: _selectedColor == '#1565C0', onTap: () => setState(() => _selectedColor = '#1565C0')),
                  _ColorPickerOption(colorHex: '#D32F2F', isSelected: _selectedColor == '#D32F2F', onTap: () => setState(() => _selectedColor = '#D32F2F')),
                  _ColorPickerOption(colorHex: '#8E24AA', isSelected: _selectedColor == '#8E24AA', onTap: () => setState(() => _selectedColor = '#8E24AA')),
                ],
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
            color: isSelected ? Color(int.parse(colorHex.replaceAll('#', '0xFF'))) : Colors.transparent,
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
