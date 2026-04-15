import 'package:flutter/material.dart';

import 'src/bootstrap/app_bootstrap.dart';
import 'src/routing/app_router.dart';

class SplitwayApp extends StatefulWidget {
  const SplitwayApp({super.key});

  @override
  State<SplitwayApp> createState() => _SplitwayAppState();
}

class _SplitwayAppState extends State<SplitwayApp> {
  late final Future<BootstrapBundle> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = AppBootstrap.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapBundle>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildShell(
            home: const _BootstrapScaffold(
              title: 'Arrancando Splitway',
              subtitle: 'Preparando base local, mapa y sincronización opcional.',
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildShell(
            home: _BootstrapScaffold(
              title: 'No se pudo iniciar la app',
              subtitle: snapshot.error.toString(),
            ),
          );
        }

        final router = buildAppRouter(snapshot.requireData);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Splitway',
          theme: _theme,
          routerConfig: router,
        );
      },
    );
  }

  Widget _buildShell({required Widget home}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Splitway',
      theme: _theme,
      home: home,
    );
  }

  static final _theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF9A3412),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4EFE8),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      backgroundColor: const Color(0xFFE8DDD3),
      selectedColor: const Color(0xFFF7D9C6),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD5C6BA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9A3412), width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    useMaterial3: true,
  );
}

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
