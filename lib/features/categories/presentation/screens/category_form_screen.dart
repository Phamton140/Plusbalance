import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  late TextEditingController _nameController;
  late String _selectedColor;
  late String _selectedIcon;

  final List<String> _colors = ['#6C63FF', '#00D4AA', '#FF6B6B', '#FCA311', '#4D96FF', '#9D4EDD'];
  final List<IconData> _icons = [Icons.shopping_cart, Icons.restaurant, Icons.local_gas_station, Icons.movie, Icons.medical_services, Icons.home];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? '#6C63FF';
    _selectedIcon = widget.category?.icon ?? '57680';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    final dao = ref.read(categoriesDaoProvider);
    if (widget.category == null) {
      await dao.createCategory(CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        color: drift.Value(_selectedColor),
        icon: drift.Value(_selectedIcon),
      ));
    } else {
      await dao.updateCategory(widget.category!.copyWith(
        name: name,
        color: _selectedColor,
        icon: _selectedIcon,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Nueva Categoría' : 'Editar Categoría'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 24),
              const Text('Color:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == c ? Color(int.parse(c.replaceAll('#', '0xFF'))) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Color(int.parse(c.replaceAll('#', '0xFF'))),
                      radius: 20,
                      child: _selectedColor == c ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Icono:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _icons.map((i) {
                  final iCode = i.codePoint.toString();
                  final isSelected = _selectedIcon == iCode;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iCode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(i, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87),
                    ),
                  );
                }).toList(),
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
