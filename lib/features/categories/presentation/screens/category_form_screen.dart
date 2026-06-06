import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/theme/category_palette.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  String? _selectedColor;

  late final List<IconData> _icons = selectableCategoryIcons;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.icon ?? _icons[0].codePoint.toString();
    _selectedColor = widget.category?.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }

    final dao = ref.read(categoriesDaoProvider);

    // Validar unicidad del nombre (case-insensitive)
    final existing = await dao.findByName(name, excludeId: widget.category?.id);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya existe una categoría llamada "$name"')),
      );
      return;
    }

    // Resolver color: si el usuario no eligió, asignar uno único automáticamente
    String color;
    if (_selectedColor != null) {
      // Defensa adicional: no se debe poder asignar un color reservado.
      if (kReservedCategoryColors.contains(_selectedColor!.toLowerCase())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese color está reservado para categorías del sistema')),
        );
        return;
      }
      color = _selectedColor!;
    } else if (widget.category == null) {
      final used = await dao.getUsedColors();
      color = pickUnusedCategoryColor(used);
    } else {
      color = widget.category!.color;
    }

    if (widget.category == null) {
      await dao.createCategory(CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        color: drift.Value(color),
        icon: drift.Value(_selectedIcon),
      ));
    } else {
      await dao.updateCategory(widget.category!.copyWith(
        name: name,
        color: color,
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
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: 'El nombre debe ser único',
                ),
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
                  // Color de previsualización del icono: usa el color actual
                  // seleccionado o el primero de la paleta.
                  final previewColor = _selectedColor != null
                      ? Color(int.parse(_selectedColor!.replaceAll('#', '0xFF')))
                      : const Color(0xFF4D96FF);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iCode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? previewColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? previewColor : Colors.grey.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(i, color: isSelected ? previewColor : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Color (se asigna automáticamente para evitar duplicados):',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _ColorPalettePicker(
                selected: _selectedColor,
                onChanged: (c) => setState(() => _selectedColor = c),
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

class _ColorPalettePicker extends ConsumerWidget {
  const _ColorPalettePicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Set<String>>(
      future: ref.watch(categoriesDaoProvider).getUsedColors(),
      builder: (context, snapshot) {
        final used = (snapshot.data ?? <String>{}).map((e) => e.toLowerCase()).toSet();

        Widget swatch(String? hex, {bool isAuto = false}) {
          final c = hex == null
              ? const Color(0xFF9E9E9E)
              : Color(int.parse(hex.replaceAll('#', '0xFF')));
          final isSelected = (isAuto && selected == null) ||
              (!isAuto && selected != null && selected!.toLowerCase() == hex!.toLowerCase());
          final isUsed = hex != null && used.contains(hex.toLowerCase());
          final isReserved = hex != null &&
              kReservedCategoryColors.contains(hex.toLowerCase());

          return GestureDetector(
            onTap: isReserved ? null : () => onChanged(hex),
            child: Tooltip(
              message: isReserved
                  ? 'Reservado para categorías del sistema'
                  : (isUsed
                      ? 'Color ya en uso por otra categoría'
                      : (isAuto ? 'Asignar automáticamente' : '')),
              child: Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isReserved
                          ? c.withValues(alpha: 0.35)
                          : c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black87 : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isAuto
                        ? const Icon(Icons.auto_awesome, color: Colors.white, size: 18)
                        : (isReserved
                            ? const Icon(Icons.lock, color: Colors.white70, size: 18)
                            : null),
                  ),
                  if (isUsed)
                    Positioned(
                      right: 8,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            size: 12, color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            swatch(null, isAuto: true),
            ...kCategoryColorPalette.map((c) => swatch(c)),
            ...kReservedCategoryColors
                .where((c) => !kCategoryColorPalette.contains(c))
                .map((c) => swatch(c)),
          ],
        );
      },
    );
  }
}
