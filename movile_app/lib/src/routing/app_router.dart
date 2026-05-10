import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../data/repositories/local_draft_repository.dart';
import '../features/editor/route_editor_controller.dart';
import '../features/editor/route_editor_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_shell.dart';
import '../features/session/live_session_controller.dart';
import '../features/session/live_session_screen.dart';
import '../services/sync/sync_service.dart';

class AppRouter {
  AppRouter({
    required this.repository,
    required this.config,
    this.syncService,
  })  : _editorController = RouteEditorController(repository),
        _sessionController = LiveSessionController(repository);

  final LocalDraftRepository repository;
  final AppConfig config;
  final SyncService? syncService;
  final RouteEditorController _editorController;
  final LiveSessionController _sessionController;

  late final GoRouter router = GoRouter(
    initialLocation: '/editor',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/editor',
                builder: (_, __) => RouteEditorScreen(
                  controller: _editorController,
                  config: config,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/session',
                builder: (_, __) => LiveSessionScreen(
                  controller: _sessionController,
                  config: config,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, __) => HistoryScreen(
                  repository: repository,
                  config: config,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  void dispose() {
    _editorController.dispose();
    _sessionController.dispose();
  }
}
