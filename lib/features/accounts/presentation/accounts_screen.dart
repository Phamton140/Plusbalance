import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../domain/account_constants.dart';
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
              return _AccountCard(account: account, isDefault: false);
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
  final bool isDefault;

  const _AccountCard({required this.account, required this.isDefault});

  bool get isAlcancia => account.id == alcanciaDefaultAccountId;
  bool get isEfectivo => account.id == efectivoDefaultAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isAlcancia) {
      return _AlcanciaCard(account: account, isDefault: isDefault);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showOptions(context, ref),
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
              ),
              if (_hasRecharge(account)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.autorenew, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _rechargeFooterText(account),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasRecharge(Account a) {
    final f = a.rechargeFrequency;
    return f != null && f.isNotEmpty && f != 'none';
  }

  String _rechargeFooterText(Account a) {
    final freq = a.rechargeFrequency;
    final label = kRechargeFrequencyLabels[freq] ?? freq ?? '';
    final concept = a.rechargeLabel?.isNotEmpty == true ? ' · ${a.rechargeLabel}' : '';
    final isBiweekly = freq == 'biweekly';

    String formatSlot(DateTime? next, double? amount, String slotLabel) {
      if (next == null) return '';
      final today = DateTime.now();
      final days = next.difference(DateTime(today.year, today.month, today.day)).inDays;
      String when;
      if (days < 0) {
        when = 'vencida (${-days}d)';
      } else if (days == 0) {
        when = 'hoy';
      } else if (days == 1) {
        when = 'mañana';
      } else if (days <= 7) {
        when = 'en ${days}d';
      } else {
        when = '${next.day}/${next.month}';
      }
      final money = amount != null ? ' \$${amount.toStringAsFixed(0)}' : '';
      final slot = isBiweekly ? '$slotLabel ' : '';
      return '· $slot$when$money';
    }

    final slot1 = formatSlot(a.rechargeNextDate, a.rechargeAmount, '1ra');
    final slot2 = isBiweekly ? formatSlot(a.rechargeNextDate2, a.rechargeAmount2, '2da') : '';

    if (a.rechargeNextDate == null && (a.rechargeNextDate2 == null || !isBiweekly)) {
      return 'Recarga $label$concept';
    }
    return 'Recarga $label$concept $slot1 $slot2'.trim();
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
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
                leading: Icon(isEfectivo ? Icons.tune : Icons.edit, color: isEfectivo ? Colors.teal : Colors.blue),
                title: Text(
                  isEfectivo ? 'Ajustar saldo / recurrencia' : 'Editar Cuenta',
                  style: TextStyle(color: isEfectivo ? Colors.teal : Colors.blue),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)));
                },
              ),
              if (!isEfectivo && !isAlcancia)
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

class _AlcanciaCard extends StatelessWidget {
  final Account account;
  final bool isDefault;

  const _AlcanciaCard({required this.account, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.shade700, Colors.amber.shade500],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.savings, size: 120, color: Colors.white.withValues(alpha: 0.15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        account.institutionName ?? 'Alcancía',
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      if (isDefault) const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
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
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.savings, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Dinero reservado para metas',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}