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
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
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
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
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
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
