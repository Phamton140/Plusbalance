import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesDaoProvider).watchAllCategories();
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Categorías'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No hay categorías registradas.'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(cat.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.2),
                  child: Icon(
                    IconData(int.parse(cat.icon), fontFamily: 'MaterialIcons'),
                    color: Color(int.parse(cat.color.replaceAll('#', '0xFF'))),
                  ),
                ),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showCategoryDialog(context, ref, cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, cat),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, Category? existingCat) {
    final nameController = TextEditingController(text: existingCat?.name ?? '');
    String selectedColor = existingCat?.color ?? '#6C63FF';
    String selectedIcon = existingCat?.icon ?? '57680';

    final colors = ['#6C63FF', '#00D4AA', '#FF6B6B', '#FCA311', '#4D96FF', '#9D4EDD'];
    final icons = [Icons.shopping_cart, Icons.restaurant, Icons.local_gas_station, Icons.movie, Icons.medical_services, Icons.home];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingCat == null ? 'Nueva Categoría' : 'Editar Categoría'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Color:'),
                    Wrap(
                      spacing: 8,
                      children: colors.map((c) => GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: CircleAvatar(
                          backgroundColor: Color(int.parse(c.replaceAll('#', '0xFF'))),
                          radius: 16,
                          child: selectedColor == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Icono:'),
                    Wrap(
                      spacing: 8,
                      children: icons.map((i) {
                        final iCode = i.codePoint.toString();
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = iCode),
                          child: CircleAvatar(
                            backgroundColor: selectedIcon == iCode ? Colors.grey.shade300 : Colors.transparent,
                            child: Icon(i, color: Colors.black87),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final dao = ref.read(categoriesDaoProvider);
                    if (existingCat == null) {
                      await dao.createCategory(CategoriesCompanion.insert(
                        id: const Uuid().v4(),
                        name: nameController.text.trim(),
                        color: selectedColor,
                        icon: selectedIcon,
                      ));
                    } else {
                      await dao.updateCategory(existingCat.copyWith(
                        name: nameController.text.trim(),
                        color: selectedColor,
                        icon: selectedIcon,
                      ));
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Estás a punto de eliminar "${cat.name}". Esto no borrará tus transacciones, pero quedarán sin categoría.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(categoriesDaoProvider).deleteCategory(cat.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }
}
