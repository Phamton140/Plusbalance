import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/pin_screen.dart';
import 'features/auth/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa los datos de localización del paquete `intl` para los
  // locales que usa la app (es en historial y PDF). Sin esto, cualquier
  // DateFormat con un locale que no sea 'en_US' lanza
  // LocaleDataException al formatear.
  await initializeDateFormatting('es', null);

  // Captura cualquier error no manejado y lo muestra en consola con
  // contexto (útil para depurar fallos silenciosos como el de
  // flutter_secure_storage que no propagan al UI).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('UNCAUGHT: ${details.exceptionAsString()}');
  };

  runApp(
    const ProviderScope(
      child: PlusBalanceApp(),
    ),
  );
}

class PlusBalanceApp extends ConsumerStatefulWidget {
  const PlusBalanceApp({super.key});

  @override
  ConsumerState<PlusBalanceApp> createState() => _PlusBalanceAppState();
}

class _PlusBalanceAppState extends ConsumerState<PlusBalanceApp> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final auth = ref.watch(authStateProvider);

    if (auth.isLoading) {
      return MaterialApp(
        title: '+Balance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const _SplashScreen(),
      );
    }

    if (!auth.isAuthenticated) {
      return MaterialApp(
        title: '+Balance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const PinScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '+Balance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando +Balance...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
