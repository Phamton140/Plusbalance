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
  late String _selectedIcon;

  // Icons: shopping_cart, restaurant, directions_bus (Autobús), movie, medical_services, home, church, flight
  final List<IconData> _icons = [
    Icons.shopping_cart, 
    Icons.restaurant, 
    Icons.directions_bus, 
    Icons.movie, 
    Icons.medical_services, 
    Icons.home,
    Icons.church,
    Icons.flight,
  ];

  // Colors mapped to the index of the icon
  final List<String> _iconColors = [
    '#6C63FF', // shopping_cart
    '#00D4AA', // restaurant
    '#FF6B6B', // directions_bus
    '#FCA311', // movie
    '#4D96FF', // medical_services
    '#9D4EDD', // home
    '#795548', // church
    '#00BCD4', // flight
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.icon ?? _icons[0].codePoint.toString();
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

    // Assign color deterministically based on icon
    int iconIndex = _icons.indexWhere((i) => i.codePoint.toString() == _selectedIcon);
    if (iconIndex == -1) iconIndex = 0;
    final determinedColor = _iconColors[iconIndex];

    final dao = ref.read(categoriesDaoProvider);
    if (widget.category == null) {
      await dao.createCategory(CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        color: drift.Value(determinedColor),
        icon: drift.Value(_selectedIcon),
      ));
    } else {
      await dao.updateCategory(widget.category!.copyWith(
        name: name,
        color: determinedColor,
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
              const Text('Icono (El color se asignará automáticamente):', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _icons.asMap().entries.map((entry) {
                  final i = entry.value;
                  final index = entry.key;
                  final iCode = i.codePoint.toString();
                  final isSelected = _selectedIcon == iCode;
                  final iconColor = Color(int.parse(_iconColors[index].replaceAll('#', '0xFF')));
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iCode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? iconColor.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? iconColor : Colors.grey.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(i, color: isSelected ? iconColor : Colors.black87),
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
