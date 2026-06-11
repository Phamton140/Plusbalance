import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../auth/presentation/pin_screen.dart';
import 'screens/edit_name_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _username = 'Usuario Balance';

  String get _initials {
    if (_username.isEmpty) return "?";
    final parts = _username.split(" ").where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final settingsDao = ref.read(settingsDaoProvider);
    final savedName = await settingsDao.getSetting('profile_username');
    if (mounted) {
      setState(() {
        if (savedName != null) _username = savedName;
      });
    }
  }

  Future<void> _editUsername() async {
    final newName = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => EditNameScreen(currentName: _username)),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => _username = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Hero(
                  tag: 'avatar_profile',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF6C63FF),
                    child: Text(
                      _initials,
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _username,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: _editUsername,
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Configuraciones', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  secondary: const Icon(Icons.dark_mode),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar PIN de acceso'),
                  subtitle: const Text('Actualiza tu PIN de 6 dígitos'),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PinScreen(forChange: true)),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Administrar Categorías'),
                  subtitle: const Text('Crea y edita tus categorías de gastos'),
                  onTap: () => context.push('/categories'),
                ),
const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Restablecer Datos', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Borra historial, servicios, metas y cuentas personalizadas', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('⚠️ Peligro'),
                        content: const Text('¿Estás 100% seguro? Esta acción borrará tus transacciones, servicios, metas y cuentas personalizadas. La cuenta "Efectivo" y las categorías por defecto se conservarán. No se puede deshacer.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Borrar Todo')
                          ),
                        ],
                      )
                    );

                    if (confirm == true) {
                      final db = ref.read(databaseProvider);
                      await db.transaction(() async {
                        await db.delete(db.transactions).go();
                        await db.delete(db.services).go();
                        await db.delete(db.goals).go();
                        await (db.delete(db.accounts)..where((a) => a.id.isNotIn([efectivoDefaultAccountId]))).go();
                        await (db.delete(db.categories)..where((c) => c.id.isNotIn(defaultCategoryIds))).go();
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos restablecidos. Cuenta "Efectivo" y categorías por defecto conservadas.')));
                        context.go('/');
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.orange)),
                  subtitle: const Text('Vuelve a la pantalla de PIN', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cerrar Sesión'),
                        content: const Text('¿Quieres cerrar la sesión actual? Necesitarás tu PIN para volver a entrar.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Cerrar')
                          ),
                        ],
                      )
                    );

                    if (confirm == true && context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const PinScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
