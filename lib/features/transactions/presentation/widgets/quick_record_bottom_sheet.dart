import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/app_database.dart';

class QuickRecordBottomSheet extends ConsumerStatefulWidget {
  const QuickRecordBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickRecordBottomSheet(),
    );
  }

  @override
  ConsumerState<QuickRecordBottomSheet> createState() => _QuickRecordBottomSheetState();
}

class _QuickRecordBottomSheetState extends ConsumerState<QuickRecordBottomSheet> {
  String _amount = "0";
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

  void _onKeyPress(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = "0";
        }
      } else if (key == '.') {
        if (!_amount.contains('.')) {
          _amount += '.';
        }
      } else {
        if (_amount == "0") {
          _amount = key;
        } else if (_amount.replaceAll('.', '').length < 9) {
          _amount += key;
        }
      }
    });
  }

  void _saveTransaction() async {
    if (_amount == '0' || _selectedAccountId == null) return;
    if (_type == 'transfer' && _destinationAccountId == null) return;

    final amountDouble = double.parse(_amount);
    final transactionsDao = ref.read(transactionsDaoProvider);

    if (_type == 'transfer') {
      if (_selectedAccountId == _thirdPartyId && _destinationAccountId == _thirdPartyId) {
        // Invalido
        return;
      }
      
      final descriptionText = _thirdPartyController.text.trim();
      final finalDescription = descriptionText.isNotEmpty ? descriptionText : 'Tercero';

      if (_selectedAccountId == _thirdPartyId) {
        // Ingreso desde un tercero
        await transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            amount: amountDouble,
            date: DateTime.now(),
            type: 'income',
            accountId: _destinationAccountId!,
            description: drift.Value('De: $finalDescription'),
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
            description: drift.Value('Para: $finalDescription'),
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

  Widget _buildAccountSelector(List<Account> accounts, String? selectedId, Function(String?) onChanged, String label, {bool allowThirdParty = false}) {
    final List<DropdownMenuItem<String>> items = accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList();
    
    if (allowThirdParty) {
      items.insert(0, const DropdownMenuItem(value: 'THIRD_PARTY', child: Text('A Tercero', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber))));
    }

    // Verify if selectedId is still valid, else null
    final validSelectedId = items.any((i) => i.value == selectedId) ? selectedId : null;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: validSelectedId,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 12)),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildKeyboard() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((key) {
              return _KeypadButton(
                text: key,
                onTap: () => _onKeyPress(key),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Container(
      height: MediaQuery.of(context).size.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: accountsAsync.when(
        data: (accounts) {
          final effectiveSelectedAccount = _selectedAccountId ?? (accounts.isNotEmpty ? accounts.first.id : null);
          
          final isThirdPartyInvolved = _type == 'transfer' && (_selectedAccountId == _thirdPartyId || _destinationAccountId == _thirdPartyId);
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final isKeyboardOpen = bottomInset > 0;

          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                    IconButton(icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_amount, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2, color: colorScheme.onSurface)),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'expense', label: Container(width: 70, alignment: Alignment.center, child: const Text('Gasto', style: TextStyle(fontSize: 12)))),
                    ButtonSegment(value: 'income', label: Container(width: 70, alignment: Alignment.center, child: const Text('Ingreso', style: TextStyle(fontSize: 12)))),
                    ButtonSegment(value: 'transfer', label: Container(width: 70, alignment: Alignment.center, child: const Text('Transferir', style: TextStyle(fontSize: 12)))),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) => setState(() => _type = set.first),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_type == 'transfer')
                          Column(
                            children: [
                              Row(children: [
                                Expanded(child: _buildAccountSelector(accounts, effectiveSelectedAccount, (val) => setState(() => _selectedAccountId = val), 'Origen', allowThirdParty: true)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward, color: colorScheme.onSurface),
                                const SizedBox(width: 8),
                                Expanded(child: _buildAccountSelector(accounts, _destinationAccountId, (val) => setState(() => _destinationAccountId = val), 'Destino', allowThirdParty: true)),
                              ]),
                              if (isThirdPartyInvolved) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _thirdPartyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Descripción / Motivo del Tercero',
                                    hintText: 'Ej. Juan Perez',
                                    isDense: true,
                                  ),
                                ),
                              ]
                            ],
                          )
                        else
                          _buildAccountSelector(accounts, effectiveSelectedAccount, (val) => setState(() => _selectedAccountId = val), 'Cuenta'),
                        
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descController,
                          decoration: const InputDecoration(labelText: 'Descripción (Opcional)', isDense: true, labelStyle: TextStyle(fontSize: 12)),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, child) {
                            final catsAsync = ref.watch(allCategoriesStreamProvider);
                            return catsAsync.when(
                              data: (cats) {
                                return DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedCategoryId,
                                  decoration: const InputDecoration(labelText: 'Categoría', isDense: true, labelStyle: TextStyle(fontSize: 12)),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Ninguna', style: TextStyle(fontSize: 12))),
                                    ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Color(int.parse(c.color.replaceAll('#', '0xFF'))))))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                                );
                              },
                              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                              error: (_, __) => const SizedBox(),
                            );
                          }
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                if (!isKeyboardOpen) ...[
                  _buildKeyboard(),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_amount != "0" && effectiveSelectedAccount != null && !(_selectedAccountId == _thirdPartyId && _destinationAccountId == _thirdPartyId)) ? () {
                      _selectedAccountId = effectiveSelectedAccount;
                      _saveTransaction();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text("Guardar"),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _KeypadButton({required this.text, required this.onTap});

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isPressed ? colorScheme.onSurface.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.text == '⌫' ? 24 : 32,
              fontWeight: FontWeight.w600,
              color: widget.text == '⌫' ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
