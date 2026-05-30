import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAccountsStream = ref.watch(activeAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuentas y Tarjetas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: activeAccountsStream.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Text(
                'No tienes cuentas. Crea una nueva.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return GestureDetector(
                onTap: () => _showAccountMenu(context, ref, account),
                child: _CreditCardVisual(account: account),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAccountDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Tarjeta/Cuenta'),
      ),
    );
  }

  void _showCreateAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final institutionController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedColor = '#6C63FF';

    final colors = ['#6C63FF', '#00D4AA', '#FF6B6B', '#FCA311', '#1A1A2E'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Registrar Entidad'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre o Alias', hintText: 'Ej. Débito Principal'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: institutionController,
                      decoration: const InputDecoration(labelText: 'Banco / Institución', hintText: 'Ej. Banco XYZ'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Balance Actual', hintText: '0.00'),
                    ),
                    const SizedBox(height: 24),
                    const Align(alignment: Alignment.centerLeft, child: Text("Color de Tarjeta", style: TextStyle(fontSize: 12, color: Colors.white54))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: colors.map((c) => GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(int.parse(c.replaceAll('#', '0xFF'))),
                          child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      )).toList(),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final balance = double.tryParse(balanceController.text) ?? 0.0;
                    final name = nameController.text.trim();
                    final institution = institutionController.text.trim();
                    
                    if (name.isNotEmpty) {
                      final dao = ref.read(accountsDaoProvider);
                      await dao.createAccount(
                        AccountsCompanion.insert(
                          id: const Uuid().v4(),
                          name: name,
                          institutionName: drift.Value(institution.isEmpty ? 'Entidad Desconocida' : institution),
                          type: 'bank',
                          color: drift.Value(selectedColor),
                          balance: drift.Value(balance),
                        )
                      );
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

  void _showAccountMenu(BuildContext context, WidgetRef ref, Account account) async {
    final settingsDao = ref.read(settingsDaoProvider);
    final defaultAccountId = await settingsDao.getSetting('default_account_id');
    final isDefault = defaultAccountId == account.id;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isDefault ? Icons.star : Icons.star_border, color: Colors.orange),
                title: Text(isDefault ? 'Ya es tu método principal' : 'Establecer como Predeterminado'),
                onTap: () async {
                  await settingsDao.setSetting('default_account_id', account.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta predeterminada actualizada')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar Cuenta', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  // Validar que no haya transacciones primero
                  final txs = await ref.read(transactionsDaoProvider).watchRecentTransactions(limit: 1).first;
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

class _CreditCardVisual extends StatelessWidget {
  final Account account;
  
  const _CreditCardVisual({required this.account});

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(int.parse(account.color.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            bgColor.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          // Glassmorphism overlay
          Positioned(
            right: -50,
            top: -50,
            child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withValues(alpha: 0.1)),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: CircleAvatar(radius: 60, backgroundColor: Colors.black.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      account.institutionName ?? 'Banco',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const Icon(Icons.wifi, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  account.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("SALDO VIGENTE", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                        Text(
                          "\$ ${account.balance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    // Simulated chip or logo
                    Icon(Icons.credit_card, size: 36, color: Colors.white.withValues(alpha: 0.8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final activeAccountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountsDaoProvider).watchActiveAccounts();
});
