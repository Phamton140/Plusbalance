import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/app_database.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _type = 'expense';
  String? _selectedAccountId;
  String? _destinationAccountId;
  String? _selectedCategoryId;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _thirdPartyController = TextEditingController();

  final _thirdPartyId = 'THIRD_PARTY';

  @override
  void initState() {
    super.initState();
    _loadDefaultAccount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _thirdPartyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultAccount() async {
    final settingsDao = ref.read(settingsDaoProvider);
    final defaultId = await settingsDao.getSetting('default_account_id');
    if (defaultId != null && mounted) {
      setState(() => _selectedAccountId = defaultId);
    }
  }

  void _saveTransaction(List<Account> accounts) async {
    final amountDouble = double.tryParse(_amountController.text) ?? 0.0;
    if (amountDouble <= 0 || _selectedAccountId == null) return;
    if (_type == 'transfer' && _destinationAccountId == null) return;
    
    // Balance validation
    if (_type == 'expense' || (_type == 'transfer' && _selectedAccountId != _thirdPartyId)) {
      final originAccount = accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => throw Exception('Cuenta no encontrada'));
      if (originAccount.balance < amountDouble) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saldo insuficiente en ${originAccount.name}')));
        return;
      }
    }

    final transactionsDao = ref.read(transactionsDaoProvider);

    if (_type == 'transfer') {
      if (_selectedAccountId == _thirdPartyId && _destinationAccountId == _thirdPartyId) {
        return;
      }

      final descriptionText = _thirdPartyController.text.trim();
      // Para transferencias la categoria es siempre 'Transferencia'
      // (no se muestra el dropdown en la UI; se asigna aqui).
      const transferCategoryId = transferenciaDefaultCategoryId;

      if (_selectedAccountId == _thirdPartyId) {
        // Ingreso desde un tercero
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: 'income',
            accountId: _destinationAccountId!,
            categoryId: const drift.Value(transferCategoryId),
            description: drift.Value(descriptionText.isNotEmpty
                ? descriptionText
                : 'Tercero'),
          ),
          _destinationAccountId!,
          amountDouble,
          true,
        );
      } else if (_destinationAccountId == _thirdPartyId) {
        // Gasto hacia un tercero
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: 'expense',
            accountId: _selectedAccountId!,
            categoryId: const drift.Value(transferCategoryId),
            description: drift.Value(descriptionText.isNotEmpty
                ? descriptionText
                : 'Tercero'),
          ),
          _selectedAccountId!,
          amountDouble,
          false,
        );
      } else {
        // Transferencia Normal
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: 'transfer',
            accountId: _selectedAccountId!,
            categoryId: const drift.Value(transferCategoryId),
            description: const drift.Value('Transferencia enviada'),
          ),
          _selectedAccountId!,
          amountDouble,
          false,
        );
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: 'transfer',
            accountId: _destinationAccountId!,
            categoryId: const drift.Value(transferCategoryId),
            description: const drift.Value('Transferencia recibida'),
          ),
          _destinationAccountId!,
          amountDouble,
          true,
        );
      }
    } else {
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: _type,
            accountId: _selectedAccountId!,
            categoryId: drift.Value(_selectedCategoryId),
            description: drift.Value(_descController.text.trim().isNotEmpty ? _descController.text.trim() : "Registro Rápido"),
          ),
          _selectedAccountId!,
          amountDouble,
          _type == 'income',
        );
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildAccountSelector(List<Account> accounts, String? selectedId, Function(String?) onChanged, String label, {bool allowThirdParty = false, bool requireBalance = false}) {
    List<Account> filteredAccounts = accounts;
    if (requireBalance) {
      filteredAccounts = accounts.where((a) => a.balance > 0).toList();
    }

    final List<DropdownMenuItem<String>> items = filteredAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (\$${a.balance.toStringAsFixed(2)})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))).toList();
    
    if (allowThirdParty) {
      items.insert(0, const DropdownMenuItem(value: 'THIRD_PARTY', child: Text('A Tercero', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber))));
    }

    final validSelectedId = items.any((i) => i.value == selectedId) ? selectedId : (items.isNotEmpty && !allowThirdParty ? items.first.value : null);

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: validSelectedId,
      decoration: InputDecoration(labelText: label),
      items: items.isEmpty && !allowThirdParty ? [const DropdownMenuItem(value: null, child: Text('Sin cuentas disponibles'))] : items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Transacción')),
      body: accountsAsync.when(
        data: (accounts) {
          final isThirdPartyInvolved = _type == 'transfer' && (_selectedAccountId == _thirdPartyId || _destinationAccountId == _thirdPartyId);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Gasto')),
                      ButtonSegment(value: 'income', label: Text('Ingreso')),
                      ButtonSegment(value: 'transfer', label: Text('Transferir')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) {
                      setState(() {
                        _type = set.first;
                        _selectedAccountId = null;
                        _destinationAccountId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  if (_type == 'transfer')
                    Column(
                      children: [
                        _buildAccountSelector(accounts, _selectedAccountId, (val) => setState(() => _selectedAccountId = val), 'Origen', allowThirdParty: true, requireBalance: true),
                        const SizedBox(height: 16),
                        const Icon(Icons.arrow_downward, color: Colors.grey),
                        const SizedBox(height: 16),
                        _buildAccountSelector(accounts, _destinationAccountId, (val) => setState(() => _destinationAccountId = val), 'Destino', allowThirdParty: true, requireBalance: false),
                        
                        if (isThirdPartyInvolved) ...[
                          const SizedBox(height: 24),
                          TextField(
                            controller: _thirdPartyController,
                            decoration: const InputDecoration(
                              labelText: 'Descripción / Motivo del Tercero',
                              hintText: 'Ej. Juan Perez',
                            ),
                          ),
                        ]
                      ],
                    )
                  else
                    _buildAccountSelector(accounts, _selectedAccountId, (val) => setState(() => _selectedAccountId = val), 'Cuenta', requireBalance: _type == 'expense'),
                  
                  const SizedBox(height: 24),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Descripción (Opcional)'),
                  ),
                  // El campo de categoría se oculta en transferencias porque
                  // se asigna automáticamente 'Transferencia'.
                  if (_type != 'transfer') ...[
                    const SizedBox(height: 24),
                    Consumer(
                      builder: (context, ref, child) {
                        final catsAsync = ref.watch(allCategoriesStreamProvider);
                        return catsAsync.when(
                          data: (cats) {
                            // Filtramos la categoría 'Transferencia' para que
                            // no pueda elegirse manualmente (es exclusiva de
                            // transferencias entre cuentas / hacia terceros).
                            final filtered = cats
                                .where((c) => c.id != transferenciaDefaultCategoryId)
                                .toList();
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: filtered.any((c) => c.id == _selectedCategoryId)
                                  ? _selectedCategoryId
                                  : null,
                              decoration: const InputDecoration(labelText: 'Categoría'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Ninguna')),
                                ...filtered.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Color(int.parse(
                                                  c.color.replaceAll('#', '0xFF'))))),
                                    )),
                              ],
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const SizedBox(),
                        );
                      }
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.sync_alt, size: 16, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text(
                          'Categoría automática: $transferenciaDefaultCategoryName',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.teal,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_selectedAccountId != null && !(_selectedAccountId == _thirdPartyId && _destinationAccountId == _thirdPartyId)) ? () {
                        _saveTransaction(accounts);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text("Guardar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
