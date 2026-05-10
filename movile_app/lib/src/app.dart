import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'data/local/splitway_local_database.dart';
import 'data/repositories/local_draft_repository.dart';
import 'data/repositories/supabase_repository.dart';
import 'routing/app_router.dart';
import 'services/sync/sync_service.dart';

class SplitwayApp extends StatefulWidget {
  const SplitwayApp({
    super.key,
    required this.config,
    required this.database,
  });

  final AppConfig config;
  final SplitwayLocalDatabase database;

  @override
  State<SplitwayApp> createState() => _SplitwayAppState();
}

class _SplitwayAppState extends State<SplitwayApp> {
  late final LocalDraftRepository _repository;
  late final AppRouter _router;
  SyncService? _syncService;

  @override
  void initState() {
    super.initState();
    _repository = LocalDraftRepository(widget.database);

    // Wire up Supabase sync if credentials + auth are available.
    if (widget.config.hasSupabase) {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        _syncService = SyncService(
          local: _repository,
          remote: SupabaseRepository(client),
        );
      }
    }

    _router = AppRouter(
      repository: _repository,
      config: widget.config,
      syncService: _syncService,
    );
  }

  @override
  void dispose() {
    _syncService?.dispose();
    _router.dispose();
    _repository.dispose();
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Splitway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router.router,
    );
  }
}
