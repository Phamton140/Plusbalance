import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';
import 'screens/account_form_screen.dart';

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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)),
                  );
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
