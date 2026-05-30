import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas y Tarjetas')),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('Aún no tienes cuentas registradas', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _AccountCard(account: account);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAccountDialog(BuildContext context, WidgetRef ref, {Account? account}) {
    final nameController = TextEditingController(text: account?.name);
    final bankController = TextEditingController(text: account?.institutionName);
    final balanceController = TextEditingController(text: account?.balance.toString() ?? '');
    String selectedColor = account?.color ?? '#1a1a2e';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(account == null ? 'Nueva Cuenta' : 'Editar Cuenta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: bankController,
                      decoration: const InputDecoration(labelText: 'Institución (Ej. Banco BHD)', hintText: 'Banco'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Alias (Ej. Tarjeta Gold)', hintText: 'Alias de cuenta'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Saldo Inicial / Actual'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Color de la tarjeta:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _ColorPickerOption(colorHex: '#1a1a2e', isSelected: selectedColor == '#1a1a2e', onTap: () => setState(() => selectedColor = '#1a1a2e')),
                        _ColorPickerOption(colorHex: '#C5A866', isSelected: selectedColor == '#C5A866', onTap: () => setState(() => selectedColor = '#C5A866')),
                        _ColorPickerOption(colorHex: '#2E7D32', isSelected: selectedColor == '#2E7D32', onTap: () => setState(() => selectedColor = '#2E7D32')),
                        _ColorPickerOption(colorHex: '#1565C0', isSelected: selectedColor == '#1565C0', onTap: () => setState(() => selectedColor = '#1565C0')),
                        _ColorPickerOption(colorHex: '#D32F2F', isSelected: selectedColor == '#D32F2F', onTap: () => setState(() => selectedColor = '#D32F2F')),
                        _ColorPickerOption(colorHex: '#8E24AA', isSelected: selectedColor == '#8E24AA', onTap: () => setState(() => selectedColor = '#8E24AA')),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final bank = bankController.text.trim();
                    final balance = double.tryParse(balanceController.text) ?? 0.0;
                    
                    if (name.isNotEmpty) {
                      if (account == null) {
                        await ref.read(accountsDaoProvider).createAccount(
                          AccountsCompanion.insert(
                            id: const Uuid().v4(),
                            name: name,
                            type: 'bank',
                            balance: drift.Value(balance),
                            institutionName: drift.Value(bank),
                            color: drift.Value(selectedColor),
                          )
                        );
                      } else {
                        await ref.read(accountsDaoProvider).updateAccount(
                          Account(
                            id: account.id,
                            name: name,
                            type: account.type,
                            balance: balance,
                            institutionName: bank,
                            color: selectedColor,
                            creditLimit: account.creditLimit,
                            cutDay: account.cutDay,
                            paymentDay: account.paymentDay,
                            interestRate: account.interestRate,
                            isArchived: account.isArchived,
                            createdAt: account.createdAt,
                            updatedAt: DateTime.now(),
                            currency: account.currency,
                          )
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<String?>(
      stream: ref.watch(settingsDaoProvider).watchSetting('default_account_id'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox();
        final defaultId = snapshot.data;
        final isDefault = defaultId == account.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _showOptions(context, ref, account, isDefault),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(int.parse(account.color.replaceAll('#', '0xFF'))),
                    Color(int.parse(account.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(int.parse(account.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        account.institutionName ?? 'Banco',
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          if (isDefault) const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          const Icon(Icons.wifi_rounded, color: Colors.white70, size: 28),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.memory, color: Colors.white54, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    '**** **** **** ${account.id.substring(account.id.length - 4).toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace', letterSpacing: 2),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name.toUpperCase(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${account.balance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Text(
                        'VISA',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, Account account, bool isDefault) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isDefault ? Icons.star_border : Icons.star, color: Colors.amber),
                title: Text(isDefault ? 'Quitar Predeterminada' : 'Marcar Predeterminada'),
                onTap: () async {
                  if (isDefault) {
                    await ref.read(settingsDaoProvider).deleteSetting('default_account_id');
                  } else {
                    await ref.read(settingsDaoProvider).setSetting('default_account_id', account.id);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar Cuenta', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  // Accessing the parent's _showAccountDialog logic safely
                  const AccountsScreen()._showAccountDialog(context, ref, account: account);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar Cuenta', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar Cuenta'),
                      content: const Text('¿Estás seguro de borrarla? Si tiene transacciones en el historial, la operación será bloqueada.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true), 
                          child: const Text('Eliminar')
                        ),
                      ],
                    )
                  );
                  
                  if (confirm != true) return;
                  
                  final txs = await ref.read(transactionsDaoProvider).watchRecentTransactions(limit: 500).first;
                  final hasTxs = txs.any((t) => t.accountId == account.id);
                  if (hasTxs && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar porque tiene transacciones vinculadas.')));
                    return;
                  }
                  
                  await ref.read(accountsDaoProvider).deleteAccount(account.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
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
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Color(int.parse(colorHex.replaceAll('#', '0xFF'))),
        child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}
