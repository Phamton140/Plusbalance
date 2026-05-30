import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import 'package:go_router/go_router.dart';

class AvatarBuilderScreen extends ConsumerWidget {
  const AvatarBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Definimos una lista de avatares pregenerados y ligeros en formato PNG.
    // Categorías: Niño, Niña, Hombre Joven, Mujer Joven, Adulto, Adulta, Anciano, Anciana, etc.
    final avatars = [
      {'name': 'Niño', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Felix&backgroundColor=c0aede'},
      {'name': 'Niña', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka&backgroundColor=ffdfbf'},
      {'name': 'Joven V.', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Jack&backgroundColor=b6e3f4'},
      {'name': 'Joven H.', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Jocelyn&backgroundColor=ffd5dc'},
      {'name': 'Adulto 1', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Brian&backgroundColor=d1d4f9'},
      {'name': 'Adulta 1', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Destiny&backgroundColor=c0aede'},
      {'name': 'Adulto 2', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Caleb&backgroundColor=ffdfbf'},
      {'name': 'Adulta 2', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Avery&backgroundColor=b6e3f4'},
      {'name': 'Anciano', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Luis&backgroundColor=d1d4f9'},
      {'name': 'Anciana', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Leah&backgroundColor=ffd5dc'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Elige tu Personaje')),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          final avatar = avatars[index];
          return GestureDetector(
            onTap: () async {
              await ref.read(settingsDaoProvider).setSetting('profile_avatar_url', avatar['url']!);
              if (context.mounted) context.pop();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.transparent,
                    backgroundImage: NetworkImage(avatar['url']!),
                  ),
                  const SizedBox(height: 12),
                  Text(avatar['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
